#if DEBUG
    import Foundation
    import Synchronization

    enum M7P0DeviceDiagnosticsScenario {
        static func makeUseCase(
            candidateRepository: any DecisionCandidateRepository,
            movieRepository: any MovieRepository,
            availabilityRepository: any AvailabilityRepository
        ) -> any ThreeForTonightUseCase {
            let state = M7P0DeviceDiagnosticsState()
            let diagnosticCandidates = M7P0DeviceDiagnosticsCandidateRepository(
                base: candidateRepository,
                state: state
            )
            let diagnosticAvailability = M7P0DiagnosticsAvailability(
                base: availabilityRepository,
                state: state
            )
            return ThreeForTonightCoordinator(
                trustedStateLoader: M7P0DeviceDiagnosticsTrustedStateLoader(),
                decisionSetRepository: M7P0TransientDecisionSetRepository(),
                inputAssembler: AssembleDecisionEngineInput(
                    candidateRepository: diagnosticCandidates,
                    movieRepository: movieRepository,
                    availabilityRepository: diagnosticAvailability
                ),
                movieRepository: movieRepository,
                availabilityRepository: diagnosticAvailability,
                signer: StableDecisionCycleSigner(),
                diagnosticsSink: M7P0ConsoleDiagnosticsSink()
            )
        }
    }

    struct M7P0DeviceDiagnosticsViewerStateUpdate: UpdateViewerMovieStateUseCase {
        func execute(
            transition _: ViewerMovieStateTransition,
            metadata _: MovieFeedbackMetadata
        ) async throws -> ViewerMovieStateChange {
            throw M7P0DeviceDiagnosticsError.mutationDisabled
        }
    }

    struct M7P0DeviceDiagnosticsCandidateRepository: DecisionCandidateRepository {
        private let base: any DecisionCandidateRepository
        private let state: M7P0DeviceDiagnosticsState

        init(
            base: any DecisionCandidateRepository,
            state: M7P0DeviceDiagnosticsState
        ) {
            self.base = base
            self.state = state
        }

        func discoverPage(
            _ page: Int,
            context: DecisionCandidateContext
        ) async throws -> [DecisionCandidateSeed] {
            let candidates = try await base.discoverPage(page, context: context)
            let finalPage = RecommendationSearchPolicy.accepted.finalExpansionPageRange.upperBound
            if page == finalPage {
                let unsuppressed = candidates.filter { !state.isSuppressed($0.movieID) }
                return unsuppressed.isEmpty ? syntheticPageCandidate(page) : unsuppressed
            }

            let candidate = candidates.first { !state.isSuppressed($0.movieID) }
                ?? syntheticCandidate(page)
            guard let candidate else { return [] }
            state.suppress(candidate.movieID)
            return [candidate]
        }

        private func syntheticPageCandidate(_ page: Int) -> [DecisionCandidateSeed] {
            syntheticCandidate(page).map { [$0] } ?? []
        }

        private func syntheticCandidate(_ page: Int) -> DecisionCandidateSeed? {
            DecisionCandidateSeed(
                movieID: 900_000 + page,
                localizedTitle: "Diagnostics candidate",
                posterPath: nil,
                backdropPath: nil,
                genres: [DecisionGenre(id: 18, name: "Drama")],
                releaseYear: 2024,
                voteAverage: 8,
                voteCount: 10000
            )
        }
    }

    struct M7P0DiagnosticsAvailability: AvailabilityRepository {
        private let base: any AvailabilityRepository
        private let state: M7P0DeviceDiagnosticsState

        init(
            base: any AvailabilityRepository,
            state: M7P0DeviceDiagnosticsState
        ) {
            self.base = base
            self.state = state
        }

        func getVerifiedEvidence(
            movieID: Int,
            region: ViewingRegion,
            policy: AvailabilityFetchPolicy
        ) async throws -> VerifiedAvailabilityEvidence? {
            let evidence = try await base.getVerifiedEvidence(
                movieID: movieID,
                region: region,
                policy: policy
            )
            return state.isSuppressed(movieID) ? nil : evidence
        }
    }

    final class M7P0DeviceDiagnosticsState: Sendable {
        private let suppressedMovieIDs = Mutex(Set<Int>())

        func suppress(_ movieID: Int) {
            _ = suppressedMovieIDs.withLock { $0.insert(movieID) }
        }

        func isSuppressed(_ movieID: Int) -> Bool {
            suppressedMovieIDs.withLock { $0.contains(movieID) }
        }
    }

    private struct M7P0DeviceDiagnosticsTrustedStateLoader: TrustedDecisionStateLoading {
        private let snapshotID = ViewerStateSnapshotID(
            rawValue: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        )

        func load() async throws -> TrustedDecisionState {
            let snapshot = try ViewerMovieStateSnapshot(
                id: snapshotID,
                recommendationSuppressionEpochID: RecommendationSuppressionEpochID(
                    rawValue: UUID(
                        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
                    )
                ),
                states: []
            )
            return TrustedDecisionState(
                profile: ViewerProfile(
                    profileSchemaVersion: ViewerProfile.currentSchemaVersion,
                    catalogID: .spainHouseholdV1,
                    region: .spain,
                    selectedServices: [.netflix],
                    reactions: [:]
                ),
                viewerMovieState: snapshot
            )
        }

        func matches(snapshotID: ViewerStateSnapshotID) async -> Bool {
            snapshotID == self.snapshotID
        }
    }

    private actor M7P0TransientDecisionSetRepository: DecisionSetRepository {
        private var committed: PersistedDecisionSet?
        private var staged: [DecisionSetPublicationTransaction: PersistedDecisionSet] = [:]

        func load() async -> DecisionSetLoadResult {
            committed.map(DecisionSetLoadResult.available) ?? .absent
        }

        func beginPublicationTransaction() async throws -> DecisionSetPublicationTransaction {
            DecisionSetPublicationTransaction()
        }

        func stage(
            _ envelope: PersistedDecisionSet,
            in transaction: DecisionSetPublicationTransaction
        ) async throws {
            staged[transaction] = envelope
        }

        func commit(_ transaction: DecisionSetPublicationTransaction) async throws {
            guard let replacement = staged.removeValue(forKey: transaction) else {
                throw M7P0DeviceDiagnosticsError.missingStagedDecisionSet
            }
            committed = replacement
        }

        func discard(_ transaction: DecisionSetPublicationTransaction) async throws {
            staged.removeValue(forKey: transaction)
        }
    }

    private struct M7P0ConsoleDiagnosticsSink: RecommendationGenerationDiagnosticsSink {
        func record(_ diagnostics: RecommendationGenerationDiagnostics) async {
            let stages = diagnostics.recallStageDurations.map {
                "\(stageName($0.stage)):\(formatted($0.duration))"
            }.joined(separator: ",")
            let firstUsable = diagnostics.timeToFirstUsableSet.map(formatted) ?? "none"
            print(
                "M7_P0_DIAGNOSTICS " +
                    "outcome=\(outcomeName(diagnostics.outcome)) " +
                    "cache=\(cacheCondition(diagnostics)) " +
                    "highestStage=\(stageName(diagnostics.highestRecallStage)) " +
                    "discoverRequests=\(diagnostics.discoverPageRequestCount) " +
                    "uniqueCandidates=\(diagnostics.uniqueRecalledCandidateCount) " +
                    "availabilityChecks=\(diagnostics.candidateAvailabilityCheckCount) " +
                    "availabilityNetworkRequests=\(diagnostics.availabilityNetworkRequestCount) " +
                    "availabilityCacheHits=\(diagnostics.availabilityCacheHitCount) " +
                    "reactionHydrations=\(diagnostics.reactionMetadataHydrationRequestCount) " +
                    "maxDiscoverConcurrency=\(diagnostics.maximumSimultaneousDiscoverRequests) " +
                    "maxAvailabilityConcurrency=\(diagnostics.maximumSimultaneousAvailabilityRequests) " +
                    "maxTasteConcurrency=\(diagnostics.maximumTasteHydrationConcurrency) " +
                    "timeToFirstUsable=\(firstUsable) " +
                    "totalDuration=\(formatted(diagnostics.totalDuration)) " +
                    "stageDurations=\(stages)"
            )
        }

        private func cacheCondition(_ diagnostics: RecommendationGenerationDiagnostics) -> String {
            switch (
                diagnostics.availabilityNetworkRequestCount,
                diagnostics.availabilityCacheHitCount
            ) {
                case (0, 0): "none"
                case (0, _): "warm"
                case (_, 0): "cold"
                default: "mixed"
            }
        }

        private func outcomeName(_ outcome: RecommendationDiagnosticOutcome) -> String {
            switch outcome {
                case .usable: "usable"
                case .exhausted: "exhausted"
                case .retryableFailure: "retryableFailure"
            }
        }

        private func stageName(_ stage: RecommendationRecallStageKind) -> String {
            switch stage {
                case .normal: "normal"
                case .firstExpansion: "firstExpansion"
                case .finalExpansion: "finalExpansion"
                case .rollover: "rollover"
            }
        }

        private func formatted(_ duration: TimeInterval) -> String {
            String(format: "%.3f", duration)
        }
    }

    private enum M7P0DeviceDiagnosticsError: Error {
        case missingStagedDecisionSet
        case mutationDisabled
    }
#endif
