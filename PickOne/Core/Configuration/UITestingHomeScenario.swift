import Foundation

struct UITestingThreeForTonightUseCase: ThreeForTonightUseCase {
    func load() async throws -> ThreeForTonightResult {
        try .usable(Self.snapshot())
    }

    func refresh() async throws -> ThreeForTonightResult {
        try .usable(Self.snapshot())
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        try .usable(Self.snapshot())
    }

    private static func snapshot() throws -> ThreeForTonightSnapshot {
        guard
            let signature = DecisionCycleSignature(
                rawValue: String(repeating: "a", count: 64)
            ),
            let cycleID = UUID(uuidString: "00000000-0000-0000-0000-000000000101"),
            let decisionSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")
        else {
            throw UITestingHomeScenarioError.invalidFixture
        }
        let genre = DecisionGenre(id: 18, name: "Drama")
        let recommendation = try PersistedDecisionRecommendation(
            role: .safeChoice,
            evidence: RecommendationEvidence(
                primary: .sparseQuality,
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: 101,
                localizedTitle: "Tonight's Movie",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 112,
                releaseYear: 2024,
                genres: [genre]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [
                    DecisionProviderSnapshot(
                        providerID: PilotStreamingService.netflix.providerID,
                        name: PilotStreamingService.netflix.name,
                        logoPath: nil,
                        productOrder: PilotStreamingService.netflix.productOrder
                    ),
                ],
                verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                regionalWatchURL: nil
            )
        )
        let cycle = try DecisionCycle(
            id: cycleID,
            identitySignature: signature,
            shownMovieIDs: [recommendation.display.movieID]
        )
        let set = try PersistedDecisionSet(
            id: decisionSetID,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engineModelVersion: .p1Model,
            cycle: cycle,
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: [recommendation]
        )
        return ThreeForTonightSnapshot(decisionSet: set, savedMovieIDs: [])
    }
}

struct UITestingMovieDetailUseCase: GetMovieDetailUseCase {
    func execute(
        id: Int,
        policy: CachePolicy
    ) async throws -> CacheResult<MovieDetailSnapshot> {
        let movie = Movie(
            id: id,
            title: id == 101 ? "Tonight's Movie" : "Similar Movie",
            originalTitle: id == 101 ? "Tonight's Movie" : "Similar Movie",
            overview: "A deterministic movie-detail fixture for UI coverage.",
            releaseDate: nil,
            runtime: 112,
            rating: 8,
            voteCount: 10000,
            posterPath: nil,
            backdropPath: nil,
            genres: [Genre(id: 18, name: "Drama")],
            tagline: nil
        )
        return CacheResult(
            value: MovieDetailSnapshot(
                movie: movie,
                similar: id == 101
                    ? [
                        MovieSummary(
                            id: 202,
                            title: "Similar Movie",
                            posterPath: nil,
                            releaseYear: 2023,
                            rating: 7.5
                        ),
                    ]
                    : [],
                isInWatchlist: false,
                isWatched: false,
                director: nil,
                topCast: [],
                isSimilarUnavailable: false,
                isCreditsUnavailable: false,
                asOf: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            isStale: false
        )
    }
}

struct UITestingAvailabilityUseCase: CheckMovieAvailabilityUseCase {
    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) async throws -> AvailabilityOutcome {
        .unknown(reason: .regionalEvidenceMissing)
    }
}

struct UITestingPreparePlaybackOptionsUseCase: PreparePlaybackOptionsUseCase {
    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) async throws -> PlaybackOptionsPreparation {
        .unavailable
    }
}

private enum UITestingHomeScenarioError: Error {
    case invalidFixture
}
