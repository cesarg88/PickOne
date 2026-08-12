import Foundation

enum DecisionEngineInputAssemblyError: Error, Equatable, Sendable {
    case profileUnavailable
    case invalidCandidateContext
    case watchlistUnavailable
    case candidateRecallFailed
    case calibrationHydrationFailed(movieID: Int)
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
    let profile: ViewerProfile
    let watchlistItems: [WatchlistItem]
    let candidates: [DecisionInputCandidate]
    let input: DecisionEngineInput
}

struct AssembleDecisionEngineInput: Sendable {
    private static let availabilityRequestLimit = 8

    private let viewerProfileRepository: any ViewerProfileRepository
    private let watchlistRepository: any WatchlistRepository
    private let recallCandidates: RecallDecisionCandidates
    private let movieRepository: any MovieRepository
    private let availabilityRepository: any AvailabilityRepository
    private let availabilityEvaluator: DecisionAvailabilityEvaluator

    init(
        viewerProfileRepository: any ViewerProfileRepository,
        watchlistRepository: any WatchlistRepository,
        candidateRepository: any DecisionCandidateRepository,
        movieRepository: any MovieRepository,
        availabilityRepository: any AvailabilityRepository,
        availabilityEvaluator: DecisionAvailabilityEvaluator = DecisionAvailabilityEvaluator()
    ) {
        self.viewerProfileRepository = viewerProfileRepository
        self.watchlistRepository = watchlistRepository
        recallCandidates = RecallDecisionCandidates(repository: candidateRepository)
        self.movieRepository = movieRepository
        self.availabilityRepository = availabilityRepository
        self.availabilityEvaluator = availabilityEvaluator
    }

    func execute(
        currentCycleShownMovieIDs: Set<Int>
    ) async throws -> DecisionEngineInputSnapshot {
        let profile = try await loadCompletedProfile()
        let watchlistItems = try loadWatchlist()
        let context = try candidateContext(for: profile)
        let tasteProfile = try await hydrateTasteProfile(profile)
        try Task.checkCancellation()

        let seeds: [DecisionCandidateSeed]
        do {
            seeds = try await recallCandidates.execute(context: context)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DecisionEngineInputAssemblyError.candidateRecallFailed
        }

        let calibrationWatchedMovieIDs = Set(
            tasteProfile.evidence.lazy
                .filter(\.reaction.meansWatchedInCalibration)
                .map(\.movieID)
        )
        let watchlistWatchedMovieIDs = Set(
            watchlistItems.lazy.filter(\.isWatched).map(\.id)
        )
        let locallyExcludedMovieIDs = calibrationWatchedMovieIDs
            .union(watchlistWatchedMovieIDs)
            .union(currentCycleShownMovieIDs)
        let locallyEligibleSeeds = seeds.filter {
            !locallyExcludedMovieIDs.contains($0.movieID)
        }
        let candidates = try await enrichAvailability(
            locallyEligibleSeeds,
            context: AvailabilityViewingContext(
                region: profile.region,
                selectedServices: profile.selectedServices
            )
        )
        let savedUnwatchedMovieIDs = Set(
            watchlistItems.lazy.filter { !$0.isWatched }.map(\.id)
        )
        let input = DecisionEngineInput(
            profile: tasteProfile,
            candidates: candidates.map(\.decisionCandidate),
            watchlistWatchedMovieIDs: watchlistWatchedMovieIDs,
            savedUnwatchedMovieIDs: savedUnwatchedMovieIDs,
            currentCycleShownMovieIDs: currentCycleShownMovieIDs
        )
        return DecisionEngineInputSnapshot(
            profile: profile,
            watchlistItems: watchlistItems,
            candidates: candidates,
            input: input
        )
    }

    private func loadCompletedProfile() async throws -> ViewerProfile {
        guard case let .completed(profile, _) = await viewerProfileRepository.loadState() else {
            throw DecisionEngineInputAssemblyError.profileUnavailable
        }
        return profile
    }

    private func loadWatchlist() throws -> [WatchlistItem] {
        do {
            return try watchlistRepository.loadAllItems()
        } catch {
            throw DecisionEngineInputAssemblyError.watchlistUnavailable
        }
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

    private func hydrateTasteProfile(
        _ profile: ViewerProfile
    ) async throws -> P1TasteProfile {
        var evidence: [TasteReactionEvidence] = []
        evidence.reserveCapacity(profile.reactions.count)

        let informativeReactions = profile.reactions.filter { $0.value.p1Value != nil }
        for movieID in informativeReactions.keys.sorted() {
            try Task.checkCancellation()
            guard let reaction = informativeReactions[movieID] else {
                continue
            }
            let movie: Movie
            do {
                movie = try await movieRepository.getMovieDetail(
                    id: movieID,
                    policy: .returnCacheElseLoad
                ).value
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw DecisionEngineInputAssemblyError.calibrationHydrationFailed(
                    movieID: movieID
                )
            }
            guard movie.id == movieID else {
                throw DecisionEngineInputAssemblyError.calibrationHydrationFailed(
                    movieID: movieID
                )
            }
            evidence.append(TasteReactionEvidence(
                movieID: movieID,
                movieTitle: movie.title,
                reaction: reaction,
                genres: Set(movie.genres.map {
                    DecisionGenre(id: $0.id, name: $0.name)
                }),
                releaseYear: movie.releaseYear
            ))
        }
        return P1TasteProfile(evidence: evidence)
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
