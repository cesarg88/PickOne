import Foundation

struct DecisionSetEnvelopeComposer: Sendable {
    private let movieRepository: any MovieRepository
    private let clock: any DecisionSetClock
    private let makeUUID: @Sendable () -> UUID

    init(
        movieRepository: any MovieRepository,
        clock: any DecisionSetClock,
        makeUUID: @escaping @Sendable () -> UUID
    ) {
        self.movieRepository = movieRepository
        self.clock = clock
        self.makeUUID = makeUUID
    }

    func makeEnvelope(
        selection: DecisionSelection,
        candidates: [DecisionInputCandidate],
        profile: ViewerProfile,
        cycle: DecisionCycle
    ) async throws -> PersistedDecisionSet {
        let candidatesByID = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.seed.movieID, $0) }
        )
        var recommendations: [PersistedDecisionRecommendation] = []
        for recommendation in selection.recommendations {
            try Task.checkCancellation()
            guard let inputCandidate = candidatesByID[recommendation.candidate.movieID] else {
                throw CoordinatorError.invariantViolation
            }
            try await recommendations.append(makeRecommendation(
                recommendation,
                inputCandidate: inputCandidate
            ))
        }
        let presentedCycle = try cycle.presenting(
            movieIDs: recommendations.map(\.display.movieID)
        )
        return try PersistedDecisionSet(
            id: makeUUID(),
            generatedAt: clock.now(),
            engineModelVersion: .p1Model,
            cycle: presentedCycle,
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            recommendations: recommendations
        )
    }

    private func makeRecommendation(
        _ recommendation: DecisionRecommendation,
        inputCandidate: DecisionInputCandidate
    ) async throws -> PersistedDecisionRecommendation {
        guard case let .eligible(providers, evidence) = inputCandidate.availabilityOutcome,
              evidence.regionalEvidence.movieID == inputCandidate.seed.movieID
        else {
            throw CoordinatorError.invariantViolation
        }
        let runtime: Int?
        do {
            let movie = try await movieRepository.getMovieDetail(
                id: inputCandidate.seed.movieID,
                policy: .returnCacheElseLoad
            ).value
            runtime = movie.id == inputCandidate.seed.movieID ? movie.runtime : nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            runtime = nil
        }
        let display = try DecisionDisplaySnapshot(
            movieID: inputCandidate.seed.movieID,
            localizedTitle: inputCandidate.seed.localizedTitle,
            posterPath: inputCandidate.seed.posterPath,
            backdropPath: inputCandidate.seed.backdropPath,
            runtimeMinutes: runtime,
            releaseYear: inputCandidate.seed.releaseYear,
            genres: inputCandidate.seed.genres.sorted { $0.id < $1.id }
        )
        let providerSnapshots = try providers.map {
            try DecisionProviderSnapshot(
                providerID: $0.id,
                name: $0.name,
                logoPath: $0.logoPath,
                productOrder: $0.productOrder
            )
        }
        let availability = try DecisionAvailabilitySnapshot(
            matchingProviders: providerSnapshots,
            verifiedAt: evidence.verifiedAt,
            regionalWatchURL: evidence.validTMDBWatchURL
        )
        return try PersistedDecisionRecommendation(
            role: recommendation.role,
            evidence: recommendation.evidence,
            display: display,
            availability: availability
        )
    }
}

struct DecisionMemberRehydrator: Sendable {
    private let movieRepository: any MovieRepository
    private let availabilityRepository: any AvailabilityRepository
    private let availabilityEvaluator: DecisionAvailabilityEvaluator

    init(
        movieRepository: any MovieRepository,
        availabilityRepository: any AvailabilityRepository,
        availabilityEvaluator: DecisionAvailabilityEvaluator
    ) {
        self.movieRepository = movieRepository
        self.availabilityRepository = availabilityRepository
        self.availabilityEvaluator = availabilityEvaluator
    }

    func rehydrate(
        _ recommendation: PersistedDecisionRecommendation,
        profile: ViewerProfile,
        forceAvailabilityReload: Bool
    ) async throws -> DecisionInputCandidate {
        let movieID = recommendation.display.movieID
        let movie = try await movieRepository.getMovieDetail(
            id: movieID,
            policy: .returnCacheElseLoad
        ).value
        guard movie.id == movieID else {
            throw CoordinatorError.invariantViolation
        }
        guard let seed = DecisionCandidateSeed(
            movieID: movieID,
            localizedTitle: recommendation.display.localizedTitle,
            posterPath: recommendation.display.posterPath,
            backdropPath: recommendation.display.backdropPath,
            genres: Set(movie.genres.map { DecisionGenre(id: $0.id, name: $0.name) }),
            releaseYear: movie.releaseYear,
            voteAverage: movie.rating,
            voteCount: movie.voteCount
        ) else {
            throw CoordinatorError.invariantViolation
        }
        let outcome = try await availabilityOutcome(
            movieID: movieID,
            profile: profile,
            forceReload: forceAvailabilityReload
        )
        let availability: DecisionAvailability = switch outcome {
            case .eligible: .eligible
            case .ineligible: .ineligible
            case .unknown: .unknown
        }
        guard let candidate = DecisionCandidate(
            movieID: movieID,
            genres: seed.genres,
            releaseYear: seed.releaseYear,
            voteAverage: seed.voteAverage,
            voteCount: seed.voteCount,
            availability: availability
        ) else {
            throw CoordinatorError.invariantViolation
        }
        return DecisionInputCandidate(
            seed: seed,
            availabilityOutcome: outcome,
            decisionCandidate: candidate
        )
    }

    private func availabilityOutcome(
        movieID: Int,
        profile: ViewerProfile,
        forceReload: Bool
    ) async throws -> AvailabilityOutcome {
        let evidence = try await availabilityRepository.getVerifiedEvidence(
            movieID: movieID,
            region: profile.region,
            policy: forceReload ? .reloadIgnoringCache : .useFreshCache
        )
        guard let evidence, evidence.regionalEvidence.movieID == movieID else {
            return .unknown(reason: .regionalEvidenceMissing)
        }
        return availabilityEvaluator.evaluate(
            evidence,
            context: AvailabilityViewingContext(
                region: profile.region,
                selectedServices: profile.selectedServices
            )
        )
    }
}
