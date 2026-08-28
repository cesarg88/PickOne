import Foundation

enum DecisionEngineInputAssemblyError: Error, Equatable, Sendable {
    case invalidCandidateContext
    case candidateRecallFailed
    case tasteHydrationFailed(movieID: Int)
    case availabilitySourceUnavailable
}

struct DecisionInputCandidate: Equatable, Sendable {
    let seed: DecisionCandidateSeed
    let availabilityOutcome: AvailabilityOutcome
    let decisionCandidate: DecisionCandidate

    var availability: DecisionAvailability {
        decisionCandidate.availability
    }
}

struct DecisionEngineInputSnapshot: Equatable, Sendable {
    let trustedState: TrustedDecisionState
    let candidates: [DecisionInputCandidate]
    let input: DecisionEngineInput
}

struct AssembleDecisionEngineInput: Sendable {
    private static let availabilityRequestLimit = 8

    private let recallCandidates: RecallDecisionCandidates
    private let tasteProfileHydrator: HydrateDecisionTasteProfile
    private let availabilityRepository: any AvailabilityRepository
    private let availabilityEvaluator: DecisionAvailabilityEvaluator

    init(
        candidateRepository: any DecisionCandidateRepository,
        movieRepository: any MovieRepository,
        availabilityRepository: any AvailabilityRepository,
        availabilityEvaluator: DecisionAvailabilityEvaluator = DecisionAvailabilityEvaluator()
    ) {
        recallCandidates = RecallDecisionCandidates(repository: candidateRepository)
        tasteProfileHydrator = HydrateDecisionTasteProfile(
            movieRepository: movieRepository
        )
        self.availabilityRepository = availabilityRepository
        self.availabilityEvaluator = availabilityEvaluator
    }

    func execute(
        trustedState: TrustedDecisionState,
        currentCycleShownMovieIDs: Set<Int>
    ) async throws -> DecisionEngineInputSnapshot {
        let context = try candidateContext(for: trustedState.profile)
        let tasteProfile: P1TasteProfile
        do {
            tasteProfile = try await tasteProfileHydrator.execute(
                reactions: trustedState.reactions
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecisionTasteProfileHydrationError {
            switch error {
                case let .movieUnavailable(movieID):
                    throw DecisionEngineInputAssemblyError.tasteHydrationFailed(
                        movieID: movieID
                    )
            }
        }
        try Task.checkCancellation()

        let seeds: [DecisionCandidateSeed]
        do {
            seeds = try await recallCandidates.execute(context: context)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DecisionEngineInputAssemblyError.candidateRecallFailed
        }

        let locallyExcludedMovieIDs = trustedState.recommendationExcludedMovieIDs
            .union(currentCycleShownMovieIDs)
        let locallyEligibleSeeds = seeds.filter {
            !locallyExcludedMovieIDs.contains($0.movieID)
        }
        let candidates = try await enrichAvailability(
            locallyEligibleSeeds,
            context: AvailabilityViewingContext(
                region: trustedState.profile.region,
                selectedServices: trustedState.profile.selectedServices
            )
        )
        let input = DecisionEngineInput(
            profile: tasteProfile,
            candidates: candidates.map(\.decisionCandidate),
            recommendationExcludedMovieIDs: trustedState.recommendationExcludedMovieIDs,
            savedUnwatchedMovieIDs: trustedState.savedUnwatchedMovieIDs,
            currentCycleShownMovieIDs: currentCycleShownMovieIDs
        )
        return DecisionEngineInputSnapshot(
            trustedState: trustedState,
            candidates: candidates,
            input: input
        )
    }

    private func candidateContext(
        for profile: ViewerProfile
    ) throws -> DecisionCandidateContext {
        guard let context = DecisionCandidateContext(
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID)
        ) else {
            throw DecisionEngineInputAssemblyError.invalidCandidateContext
        }
        return context
    }

    private func enrichAvailability(
        _ seeds: [DecisionCandidateSeed],
        context: AvailabilityViewingContext
    ) async throws -> [DecisionInputCandidate] {
        var results = [AvailabilityEnrichment?](
            repeating: nil,
            count: seeds.count
        )
        var nextIndex = 0

        try await withThrowingTaskGroup(
            of: (Int, AvailabilityEnrichment).self
        ) { group in
            func addTask(at index: Int) {
                let seed = seeds[index]
                group.addTask {
                    let enrichment = try await availabilityOutcome(
                        for: seed,
                        context: context
                    )
                    return try (
                        index,
                        AvailabilityEnrichment(
                            candidate: makeInputCandidate(
                                seed: seed,
                                outcome: enrichment.outcome
                            ),
                            requestFailed: enrichment.requestFailed
                        )
                    )
                }
            }

            while nextIndex < min(Self.availabilityRequestLimit, seeds.count) {
                addTask(at: nextIndex)
                nextIndex += 1
            }

            while let (index, enrichment) = try await group.next() {
                results[index] = enrichment
                try Task.checkCancellation()
                if nextIndex < seeds.count {
                    addTask(at: nextIndex)
                    nextIndex += 1
                }
            }
        }

        let completed = results.compactMap { $0 }
        if !completed.isEmpty, completed.allSatisfy(\.requestFailed) {
            throw DecisionEngineInputAssemblyError.availabilitySourceUnavailable
        }
        return completed.map(\.candidate)
    }

    private func availabilityOutcome(
        for seed: DecisionCandidateSeed,
        context: AvailabilityViewingContext
    ) async throws -> AvailabilityResolution {
        do {
            guard let evidence = try await availabilityRepository.getVerifiedEvidence(
                movieID: seed.movieID,
                region: context.region,
                policy: .useFreshCache
            ) else {
                return AvailabilityResolution(
                    outcome: .unknown(reason: .regionalEvidenceMissing),
                    requestFailed: false
                )
            }
            guard evidence.regionalEvidence.movieID == seed.movieID else {
                return AvailabilityResolution(
                    outcome: .unknown(reason: .regionalEvidenceMissing),
                    requestFailed: false
                )
            }
            return AvailabilityResolution(
                outcome: availabilityEvaluator.evaluate(evidence, context: context),
                requestFailed: false
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return AvailabilityResolution(
                outcome: .unknown(reason: .verificationFailed),
                requestFailed: true
            )
        }
    }

    private func makeInputCandidate(
        seed: DecisionCandidateSeed,
        outcome: AvailabilityOutcome
    ) throws -> DecisionInputCandidate {
        let availability: DecisionAvailability = switch outcome {
            case .eligible: .eligible
            case .ineligible: .ineligible
            case .unknown: .unknown
        }
        guard let candidate = DecisionCandidate(
            movieID: seed.movieID,
            genres: seed.genres,
            releaseYear: seed.releaseYear,
            voteAverage: seed.voteAverage,
            voteCount: seed.voteCount,
            availability: availability
        ) else {
            throw DecisionEngineInputAssemblyError.candidateRecallFailed
        }
        return DecisionInputCandidate(
            seed: seed,
            availabilityOutcome: outcome,
            decisionCandidate: candidate
        )
    }
}

private struct AvailabilityResolution: Sendable {
    let outcome: AvailabilityOutcome
    let requestFailed: Bool
}

private struct AvailabilityEnrichment: Sendable {
    let candidate: DecisionInputCandidate
    let requestFailed: Bool
}
