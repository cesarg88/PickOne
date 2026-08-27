import Foundation
@testable import PickOne

enum CoordinatorTestFixtures {
    static func makeCoordinator(
        profile: ViewerProfile = sparseProfile(),
        candidateRepository: CoordinatorCandidateRepository,
        availabilityRepository: CoordinatorAvailabilityRepository,
        decisionSetRepository: CoordinatorDecisionSetRepository,
        movieRepository: CoordinatorMovieRepository = CoordinatorMovieRepository(),
        watchlistRepository: any WatchlistRepository = CoordinatorWatchlistRepository(),
        snapshotID: ViewerStateSnapshotID = CoordinatorViewerMovieStateRepository.defaultSnapshotID
    ) -> ThreeForTonightCoordinator {
        let profileRepository = CoordinatorProfileRepository(profile: profile)
        return ThreeForTonightCoordinator(
            viewerProfileRepository: profileRepository,
            viewerMovieStateRepository: CoordinatorViewerMovieStateRepository(
                snapshotID: snapshotID
            ),
            watchlistRepository: watchlistRepository,
            decisionSetRepository: decisionSetRepository,
            inputAssembler: AssembleDecisionEngineInput(
                viewerProfileRepository: profileRepository,
                watchlistRepository: watchlistRepository,
                candidateRepository: candidateRepository,
                movieRepository: movieRepository,
                availabilityRepository: availabilityRepository
            ),
            movieRepository: movieRepository,
            availabilityRepository: availabilityRepository,
            signer: StableDecisionCycleSigner()
        )
    }

    static func sparseProfile() -> ViewerProfile {
        ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: [:]
        )
    }

    static func envelope(
        currentMovieIDs: [Int],
        shownMovieIDs: Set<Int>? = nil,
        profile: ViewerProfile = sparseProfile()
    ) throws -> PersistedDecisionSet {
        let signature = try StableDecisionCycleSigner().signature(for: DecisionCycleIdentity(
            engineModelVersion: .p1Model,
            profile: profile
        ))
        let roles: [DecisionRole] = [.safeChoice, .stretchChoice, .discoveryChoice]
        let recommendations = try currentMovieIDs.enumerated().map { index, movieID in
            try recommendation(movieID: movieID, role: roles[index])
        }
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: shownMovieIDs ?? Set(currentMovieIDs)
            ),
            sourceViewerStateSnapshotID: CoordinatorViewerMovieStateRepository.defaultSnapshotID,
            region: profile.region,
            selectedProviderIDs: profile.selectedServices.map(\.providerID),
            recommendations: recommendations
        )
    }

    static func candidate(_ movieID: Int) throws -> DecisionCandidateSeed {
        guard let candidate = DecisionCandidateSeed(
            movieID: movieID,
            localizedTitle: "Movie \(movieID)",
            posterPath: nil,
            backdropPath: nil,
            genres: [DecisionGenre(id: 18, name: "Drama")],
            releaseYear: 2024,
            voteAverage: 8.5,
            voteCount: 20000
        ) else {
            throw CoordinatorTestError.unavailable
        }
        return candidate
    }

    static func movie(_ movieID: Int) -> Movie {
        Movie(
            id: movieID,
            title: "Movie \(movieID)",
            originalTitle: "Movie \(movieID)",
            overview: "Overview",
            releaseDate: Date(timeIntervalSince1970: 1_704_067_200),
            runtime: 100,
            rating: 8.5,
            voteCount: 20000,
            posterPath: nil,
            backdropPath: nil,
            genres: [Genre(id: 18, name: "Drama")],
            tagline: nil
        )
    }

    static func evidence(_ movieID: Int) -> VerifiedAvailabilityEvidence {
        VerifiedAvailabilityEvidence(
            regionalEvidence: RegionalAvailabilityEvidence(
                movieID: movieID,
                region: .spain,
                watchURL: "https://www.themoviedb.org/movie/\(movieID)/watch",
                flatrate: [ProviderOfferEvidence(
                    providerID: PilotStreamingService.netflix.providerID,
                    sourceName: PilotStreamingService.netflix.name,
                    logoPath: "/netflix.jpg"
                )],
                rent: [],
                buy: [],
                ads: [],
                free: []
            ),
            verifiedAt: Date(timeIntervalSince1970: 2000)
        )
    }

    static func watchedItem(_ movieID: Int) -> WatchlistItem {
        WatchlistItem(
            id: movieID,
            addedAt: Date(timeIntervalSince1970: 3000),
            isWatched: true,
            movie: MovieSummary(
                id: movieID,
                title: "Movie \(movieID)",
                posterPath: nil,
                releaseYear: 2024,
                rating: 8.5
            )
        )
    }

    private static func recommendation(
        movieID: Int,
        role: DecisionRole
    ) throws -> PersistedDecisionRecommendation {
        let display = try DecisionDisplaySnapshot(
            movieID: movieID,
            localizedTitle: "Movie \(movieID)",
            posterPath: nil,
            backdropPath: nil,
            runtimeMinutes: 100,
            releaseYear: 2024,
            genres: [DecisionGenre(id: 18, name: "Drama")]
        )
        let provider = try DecisionProviderSnapshot(
            providerID: PilotStreamingService.netflix.providerID,
            name: PilotStreamingService.netflix.name,
            logoPath: "/netflix.jpg",
            productOrder: PilotStreamingService.netflix.productOrder
        )
        return try PersistedDecisionRecommendation(
            role: role,
            evidence: RecommendationEvidence(primary: .sparseQuality, diversity: nil),
            display: display,
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [provider],
                verifiedAt: Date(timeIntervalSince1970: 2000),
                regionalWatchURL: URL(string: "https://www.themoviedb.org/movie/\(movieID)/watch")
            )
        )
    }
}
