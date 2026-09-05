import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Three for Tonight progressive recovery")
struct ThreeForTonightProgressiveRecoveryTests {
    @Test("recall expands from pages 1 through 6 and stops on empty page 8")
    func expandsIntoFirstRecoveryStage() async throws {
        let filler = try CoordinatorTestFixtures.candidate(90)
        let winners = try [100, 101, 102].map(CoordinatorTestFixtures.candidate)
        var pages = Dictionary(
            uniqueKeysWithValues: (1 ... 6).map { ($0, [filler]) }
        )
        pages[7] = winners
        let candidates = CoordinatorCandidateRepository(candidatesByPage: pages)
        let availability = CoordinatorAvailabilityRepository(
            evidenceByMovieID: Dictionary(
                uniqueKeysWithValues: winners.map {
                    ($0.movieID, CoordinatorTestFixtures.evidence($0.movieID))
                }
            )
        )
        let movies = CoordinatorMovieRepository(movies: Dictionary(
            uniqueKeysWithValues: winners.map {
                ($0.movieID, CoordinatorTestFixtures.movie($0.movieID))
            }
        ))
        let diagnostics = RecordingRecommendationDiagnosticsSink()
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: availability,
            decisionSetRepository: CoordinatorDecisionSetRepository(loadResult: .absent),
            movieRepository: movies,
            diagnosticsSink: diagnostics
        )

        let result = try await sut.load()
        guard case let .usable(snapshot) = result else {
            Issue.record("Expected a complete set")
            return
        }

        #expect(await candidates.requestedPages == Array(1 ... 8))
        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [100, 101, 102])
        let recorded = try #require(await diagnostics.firstSnapshot())
        #expect(recorded.highestRecallStage == .firstExpansion)
        #expect(recorded.discoverPageRequestCount == 8)
        #expect(recorded.uniqueRecalledCandidateCount == 4)
        #expect(recorded.candidateAvailabilityCheckCount == 4)
        #expect(recorded.maximumSimultaneousDiscoverRequests == 1)
        #expect(recorded.maximumSimultaneousAvailabilityRequests <= 8)
        #expect(diagnosticFieldNames().isDisjoint(with: sensitiveDiagnosticNames))
    }

    @Test("a partial credible set is typed exhaustion rather than failure")
    func partialSetIsTypedExhaustion() async throws {
        let candidate = try CoordinatorTestFixtures.candidate(10)
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: [candidate]]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(loadResult: .absent),
            movieRepository: CoordinatorMovieRepository(
                movies: [10: CoordinatorTestFixtures.movie(10)]
            )
        )

        guard case let .exhausted(exhaustion) = try await sut.load() else {
            Issue.record("Expected typed partial exhaustion")
            return
        }

        #expect(exhaustion.snapshot.decisionSet.recommendations.count == 1)
        #expect(!exhaustion.canRefresh)
    }

    @Test("exhausted refresh retains a proven-safe active set")
    func exhaustedRefreshRetainsActiveSet() async throws {
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10, 11, 12]
        )
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: Dictionary(
                    uniqueKeysWithValues: [10, 11, 12].map {
                        ($0, CoordinatorTestFixtures.evidence($0))
                    }
                )
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            ),
            movieRepository: CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: [10, 11, 12].map {
                    ($0, CoordinatorTestFixtures.movie($0))
                }
            ))
        )

        guard case let .exhausted(exhaustion) = try await sut.refresh() else {
            Issue.record("Expected retained-set exhaustion")
            return
        }

        #expect(exhaustion.snapshot.decisionSet.recommendations.map(\.display.movieID) == [10, 11, 12])
        #expect(exhaustion.snapshot.decisionSet.outcome.isExhausted)
    }

    @Test(
        "one or two newly found titles replace the retained active set",
        arguments: [1, 2]
    )
    func partialNewSetReplacesRetainedSet(count: Int) async throws {
        let source = try exhaustedEnvelope(
            CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11, 12]),
            exhaustedAt: Date(timeIntervalSince1970: 1000)
        )
        let newIDs = Array(20 ..< 20 + count)
        let candidates = try newIDs.map(CoordinatorTestFixtures.candidate)
        let allIDs = [10, 11, 12] + newIDs
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: [1: candidates]
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: Dictionary(uniqueKeysWithValues: allIDs.map {
                    ($0, CoordinatorTestFixtures.evidence($0))
                })
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            ),
            movieRepository: CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: allIDs.map {
                    ($0, CoordinatorTestFixtures.movie($0))
                }
            ))
        )

        guard case let .exhausted(exhaustion) = try await sut.refresh() else {
            Issue.record("Expected partial exhausted replacement")
            return
        }

        #expect(exhaustion.snapshot.decisionSet.recommendations.map(\.display.movieID) == newIDs)
    }

    @Test("retained-member transport failure is retryable and preserves safe prefix")
    func retainedTransportFailureIsRetryable() async throws {
        let source = try exhaustedEnvelope(
            CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11, 12]),
            exhaustedAt: Date(timeIntervalSince1970: 1000)
        )
        let refreshedAt = Date(timeIntervalSince1970: 9000)
        let availability = CoordinatorAvailabilityRepository(
            evidenceByMovieID: [10: refreshedEvidence(movieID: 10, at: refreshedAt)],
            failingMovieIDs: [12]
        )
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: availability,
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: [10, 11, 12].map {
                    ($0, CoordinatorTestFixtures.movie($0))
                }
            ))
        )

        guard case let .retryableFailure(reason, retained) = try await sut.refresh() else {
            Issue.record("Expected retained-member transport failure")
            return
        }

        #expect(reason == .generationUnavailable)
        #expect(retained?.decisionSet.recommendations.map(\.display.movieID) == [10])
        #expect(
            retained?.decisionSet.recommendations.first?.availability.verifiedAt
                == refreshedAt
        )
        #expect(await Set(availability.requestedMovieIDs) == [10, 11, 12])
        #expect(await decisionSets.load() == .available(source))
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("retained-member hydration failure is retryable without persistence")
    func retainedHydrationFailureIsRetryable() async throws {
        let source = try exhaustedEnvelope(
            CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11]),
            exhaustedAt: Date(timeIntervalSince1970: 1000)
        )
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: [10: CoordinatorTestFixtures.evidence(10)]
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(
                movies: [10: CoordinatorTestFixtures.movie(10)]
            )
        )

        guard case let .retryableFailure(reason, retained) = try await sut.refresh() else {
            Issue.record("Expected retained-member hydration failure")
            return
        }

        #expect(reason == .generationUnavailable)
        #expect(retained?.decisionSet.recommendations.map(\.display.movieID) == [10])
        #expect(await decisionSets.load() == .available(source))
        #expect(await decisionSets.replacements.isEmpty)
    }

    @Test("stale post-persistence work is rolled back when regeneration fails")
    func stalePersistenceIsRolledBackBeforeFailedRegeneration() async throws {
        let current = try trustedState(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let latest = try trustedState(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let loader = MutableTrustedDecisionStateLoader(current: current, next: latest)
        let candidate = try CoordinatorTestFixtures.candidate(20)
        let candidates = CoordinatorCandidateRepository(
            candidatesByPage: [1: [candidate]],
            error: .unavailable,
            failureStartingAtRequest: 3
        )
        let decisionSets = CoordinatorDecisionSetRepository(
            loadResult: .absent,
            onReplace: loader.publishNext
        )
        let sut = coordinator(
            loader: loader,
            candidates: candidates,
            decisionSets: decisionSets,
            movieIDs: [20]
        )

        guard case let .retryableFailure(reason, _) = try await sut.load() else {
            Issue.record("Expected failed stale regeneration")
            return
        }

        #expect(reason == .generationUnavailable)
        #expect(await decisionSets.load() == .absent)
        #expect(await decisionSets.inFlightPublicationCount == 0)
        let attempted = try #require(await decisionSets.replacements.first)
        #expect(attempted.outcome.isExhausted)
        #expect(attempted.cycle.history.allShownMovieIDs == [20])
    }

    @Test("failed generation diagnostics preserve all completed work")
    func failedGenerationRecordsObservedWork() async throws {
        let diagnostics = RecordingRecommendationDiagnosticsSink()
        let source = try exhaustedEnvelope(
            CoordinatorTestFixtures.envelope(currentMovieIDs: [10, 11]),
            exhaustedAt: Date(timeIntervalSince1970: 1000)
        )
        let candidate20 = try CoordinatorTestFixtures.candidate(20)
        let candidate30 = try CoordinatorTestFixtures.candidate(30)
        var pages = Dictionary(uniqueKeysWithValues: (1 ... 6).map { ($0, [candidate20]) })
        pages[7] = [candidate30]
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: CoordinatorCandidateRepository(
                candidatesByPage: pages,
                error: .unavailable,
                failureStartingAtRequest: 8
            ),
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: Dictionary(uniqueKeysWithValues: [10, 11, 20].map {
                    ($0, CoordinatorTestFixtures.evidence($0))
                }),
                cacheHitMovieIDs: [10]
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            ),
            movieRepository: CoordinatorMovieRepository(movies: Dictionary(
                uniqueKeysWithValues: [10, 11, 20].map {
                    ($0, CoordinatorTestFixtures.movie($0))
                }
            )),
            diagnosticsSink: diagnostics
        )

        guard case .retryableFailure = try await sut.refresh() else {
            Issue.record("Expected retryable failure")
            return
        }

        let recorded = try #require(await diagnostics.firstSnapshot())
        #expect(recorded.outcome == .retryableFailure)
        #expect(recorded.highestRecallStage == .firstExpansion)
        #expect(recorded.recallStageDurations.map(\.stage) == [.normal, .firstExpansion])
        #expect(recorded.discoverPageRequestCount == 8)
        #expect(recorded.uniqueRecalledCandidateCount == 2)
        #expect(recorded.candidateAvailabilityCheckCount == 3)
        #expect(recorded.availabilityNetworkRequestCount == 2)
        #expect(recorded.availabilityCacheHitCount == 1)
        #expect(recorded.maximumSimultaneousAvailabilityRequests == 1)
    }

    @Test("fresh zero exhaustion survives relaunch and expires at exactly 24 hours")
    func zeroExhaustionFreshnessAndExplicitRetry() async throws {
        let startedAt = Date(timeIntervalSince1970: 1000)
        let clock = MutableDecisionSetClock(now: startedAt)
        let candidates = CoordinatorCandidateRepository()
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .absent)
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(),
            decisionSetRepository: decisionSets,
            clock: clock
        )

        guard case let .exhausted(initial) = try await sut.load() else {
            Issue.record("Expected zero exhaustion")
            return
        }
        #expect(initial.snapshot.decisionSet.recommendations.isEmpty)
        #expect(await candidates.requestedPages == [1])

        _ = try await sut.load()
        _ = try await sut.refresh()
        #expect(await candidates.requestedPages == [1])

        clock.setNow(startedAt.addingTimeInterval(24 * 60 * 60))
        guard case let .exhausted(expiredRetry) = try await sut.refresh() else {
            Issue.record("Expected successful re-exhaustion")
            return
        }
        #expect(await candidates.requestedPages == [1, 1])
        #expect(expiredRetry.snapshot.decisionSet.outcome == .exhausted(
            exhaustedAt: startedAt.addingTimeInterval(24 * 60 * 60)
        ))
        #expect(!expiredRetry.canRefresh)
    }

    @Test("never-shown candidates survive three-ID oldest-first rollover")
    func neverShownPriorityAndOldestRollover() async throws {
        let old = try CoordinatorTestFixtures.candidate(10)
        let neverShown = try [100, 101].map(CoordinatorTestFixtures.candidate)
        var pages = Dictionary(
            uniqueKeysWithValues: (1 ... 20).map { ($0, [old]) }
        )
        pages[1] = [old] + neverShown
        let source = try envelope(
            currentMovieIDs: [],
            history: RecommendationHistory(
                allShownMovieIDs: [10, 11, 12, 13],
                recentlyShownMovieIDs: [10, 11, 12, 13],
                suppressionEpochID: .legacyCompatibility
            )
        )
        let availability = [10, 100, 101].reduce(into: [Int: VerifiedAvailabilityEvidence]()) {
            $0[$1] = CoordinatorTestFixtures.evidence($1)
        }
        let movies = [10, 100, 101].reduce(into: [Int: Movie]()) {
            $0[$1] = CoordinatorTestFixtures.movie($1)
        }
        let candidates = CoordinatorCandidateRepository(candidatesByPage: pages)
        let decisionSets = CoordinatorDecisionSetRepository(loadResult: .available(source))
        let sut = CoordinatorTestFixtures.makeCoordinator(
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: availability
            ),
            decisionSetRepository: decisionSets,
            movieRepository: CoordinatorMovieRepository(movies: movies)
        )

        guard case let .usable(snapshot) = try await sut.refresh() else {
            Issue.record("Expected rollover to fill the set")
            return
        }

        #expect(await candidates.requestedPages == Array(1 ... 20))
        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [10, 100, 101])
        #expect(snapshot.decisionSet.cycle.history.allShownMovieIDs == [10, 11, 12, 13, 100, 101])
        #expect(!snapshot.decisionSet.cycle.history.recentlyShownMovieIDs.contains(11))
        #expect(!snapshot.decisionSet.cycle.history.recentlyShownMovieIDs.contains(12))
    }

    @Test("reaction reconciliation preserves every unaffected credible member")
    func reactionReconciliationRetainsCredibleMembers() async throws {
        let oldProfile = CoordinatorTestFixtures.sparseProfile()
        let newProfile = profile(reactions: [155: .likeIt])
        let source = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: [10, 11, 12],
            profile: oldProfile
        )
        let reaction = try viewerState(movieID: 155, reaction: .likeIt)
        let availability = [10, 11, 12].reduce(into: [Int: VerifiedAvailabilityEvidence]()) {
            $0[$1] = CoordinatorTestFixtures.evidence($1)
        }
        let movies = [10, 11, 12, 155].reduce(into: [Int: Movie]()) {
            $0[$1] = CoordinatorTestFixtures.movie($1)
        }
        let candidates = CoordinatorCandidateRepository()
        let sut = CoordinatorTestFixtures.makeCoordinator(
            profile: newProfile,
            candidateRepository: candidates,
            availabilityRepository: CoordinatorAvailabilityRepository(
                evidenceByMovieID: availability
            ),
            decisionSetRepository: CoordinatorDecisionSetRepository(
                loadResult: .available(source)
            ),
            movieRepository: CoordinatorMovieRepository(movies: movies),
            viewerMovieStates: [reaction]
        )
        let change = try #require(DecisionViewerStateChange(
            movieID: 155,
            impact: .tasteChanged,
            snapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID
        ))

        guard case let .usable(snapshot) = try await sut
            .reconcileAfterViewerStateChange(change)
        else {
            Issue.record("Expected stable reconciliation")
            return
        }

        #expect(Set(snapshot.decisionSet.recommendations.map(\.display.movieID)) == [10, 11, 12])
        #expect(snapshot.decisionSet.cycle.id != source.cycle.id)
        #expect(await candidates.requestedPages.isEmpty)
    }
}

private extension PersistedDecisionSetOutcome {
    var isExhausted: Bool {
        if case .exhausted = self { return true }
        return false
    }
}

private extension ThreeForTonightProgressiveRecoveryTests {
    var sensitiveDiagnosticNames: Set<String> {
        ["movieID", "title", "provider", "profile", "feedback"]
    }

    func diagnosticFieldNames() -> Set<String> {
        Set(Mirror(reflecting: RecommendationGenerationDiagnostics(
            outcome: .usable,
            highestRecallStage: .normal,
            totalDuration: 0,
            timeToFirstUsableSet: 0,
            recallStageDurations: [],
            discoverPageRequestCount: 0,
            uniqueRecalledCandidateCount: 0,
            candidateAvailabilityCheckCount: 0,
            availabilityNetworkRequestCount: 0,
            availabilityCacheHitCount: 0,
            reactionMetadataHydrationRequestCount: 0,
            maximumSimultaneousDiscoverRequests: 0,
            maximumSimultaneousAvailabilityRequests: 0,
            maximumTasteHydrationConcurrency: 0
        )).children.compactMap(\.label))
    }

    func envelope(
        currentMovieIDs: [Int],
        history: RecommendationHistory
    ) throws -> PersistedDecisionSet {
        let base = try CoordinatorTestFixtures.envelope(
            currentMovieIDs: currentMovieIDs
        )
        return try PersistedDecisionSet(
            id: base.id,
            generatedAt: base.generatedAt,
            engineModelVersion: base.engineModelVersion,
            cycle: DecisionCycle(
                id: base.cycle.id,
                identitySignature: base.cycle.identitySignature,
                history: history
            ),
            sourceViewerStateSnapshotID: base.sourceViewerStateSnapshotID,
            searchPolicyVersion: base.searchPolicyVersion,
            outcome: base.outcome,
            region: base.region,
            selectedProviderIDs: base.selectedProviderIDs,
            recommendations: base.recommendations
        )
    }

    func profile(reactions: [Int: CalibrationReaction]) -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: reactions
        )
    }

    func viewerState(movieID: Int, reaction: MovieReaction) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: MovieFeedbackMetadata(
                title: "Movie \(movieID)",
                releaseYear: 2024,
                posterPath: nil
            ),
            watchState: .watched,
            preference: .reaction(reaction),
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }

    func trustedState(snapshotID: ViewerStateSnapshotID) throws -> TrustedDecisionState {
        try TrustedDecisionState(
            profile: CoordinatorTestFixtures.sparseProfile(),
            viewerMovieState: ViewerMovieStateSnapshot(id: snapshotID, states: [])
        )
    }

    func refreshedEvidence(movieID: Int, at date: Date) -> VerifiedAvailabilityEvidence {
        VerifiedAvailabilityEvidence(
            regionalEvidence: CoordinatorTestFixtures.evidence(movieID).regionalEvidence,
            verifiedAt: date
        )
    }

    func exhaustedEnvelope(
        _ envelope: PersistedDecisionSet,
        exhaustedAt: Date
    ) throws -> PersistedDecisionSet {
        try PersistedDecisionSet(
            id: envelope.id,
            generatedAt: envelope.generatedAt,
            engineModelVersion: envelope.engineModelVersion,
            cycle: envelope.cycle,
            sourceViewerStateSnapshotID: envelope.sourceViewerStateSnapshotID,
            searchPolicyVersion: envelope.searchPolicyVersion,
            outcome: .exhausted(exhaustedAt: exhaustedAt),
            region: envelope.region,
            selectedProviderIDs: envelope.selectedProviderIDs,
            recommendations: envelope.recommendations
        )
    }

    func coordinator(
        loader: MutableTrustedDecisionStateLoader,
        candidates: CoordinatorCandidateRepository,
        decisionSets: CoordinatorDecisionSetRepository,
        movieIDs: [Int]
    ) -> ThreeForTonightCoordinator {
        let movies = CoordinatorMovieRepository(movies: Dictionary(
            uniqueKeysWithValues: movieIDs.map {
                ($0, CoordinatorTestFixtures.movie($0))
            }
        ))
        let availability = CoordinatorAvailabilityRepository(
            evidenceByMovieID: Dictionary(uniqueKeysWithValues: movieIDs.map {
                ($0, CoordinatorTestFixtures.evidence($0))
            })
        )
        return ThreeForTonightCoordinator(
            trustedStateLoader: loader,
            decisionSetRepository: decisionSets,
            inputAssembler: AssembleDecisionEngineInput(
                candidateRepository: candidates,
                movieRepository: movies,
                availabilityRepository: availability
            ),
            movieRepository: movies,
            availabilityRepository: availability,
            signer: StableDecisionCycleSigner()
        )
    }
}

private final class MutableDecisionSetClock: DecisionSetClock, Sendable {
    private let value: Mutex<Date>

    init(now: Date) {
        value = Mutex(now)
    }

    func now() -> Date {
        value.withLock { $0 }
    }

    func setNow(_ now: Date) {
        value.withLock { $0 = now }
    }
}
