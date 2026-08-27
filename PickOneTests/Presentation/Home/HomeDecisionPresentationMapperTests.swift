import Foundation
@testable import PickOne
import Testing

@MainActor
struct HomeDecisionPresentationMapperTests {
    @Test("maps role, evidence, providers, metadata, and transient saved state")
    func mapsRecommendation() throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot(savedMovieIDs: [101])

        let model = HomeDecisionPresentationMapper.map(snapshot: snapshot)

        let item = try #require(model.items.first)
        #expect(item.id == 101)
        #expect(item.role == "Safe Choice")
        #expect(
            item.reason == "Saved for later, and similar to Arrival, which you loved — "
                + "shares Drama and Science Fiction."
        )
        #expect(item.providers.map(\.name) == ["Netflix"])
        #expect(item.details == "2024 · 2h 3m · Drama, Science Fiction")
        #expect(item.isSaved)
    }

    @Test("direct anchor reason enumerates only shared genres")
    func directAnchorReasonEnumeratesGenres() throws {
        let recommendation = try HomeDecisionTestFixtures.recommendation(
            watchlistWrapped: false,
            sharedGenreIDs: [18]
        )
        let snapshot = try HomeDecisionTestFixtures.snapshot(
            recommendations: [recommendation]
        )

        let item = try #require(HomeDecisionPresentationMapper.map(
            snapshot: snapshot
        ).items.first)

        #expect(item.reason == "Similar to Arrival, which you loved — shares Drama.")
        #expect(!item.reason.contains("2020s"))
        #expect(!item.reason.contains("Science Fiction"))
    }

    @Test("direct anchor reason adds supported era reinforcement")
    func directAnchorReasonIncludesEraMatch() throws {
        let recommendation = try HomeDecisionTestFixtures.recommendation(
            watchlistWrapped: false,
            reaction: .liked,
            sharedGenreIDs: [18],
            eraMatch: .sameDecade(DecisionDecade(year: 2024))
        )
        let snapshot = try HomeDecisionTestFixtures.snapshot(
            recommendations: [recommendation]
        )

        let item = try #require(HomeDecisionPresentationMapper.map(
            snapshot: snapshot
        ).items.first)

        #expect(
            item.reason == "Similar to Arrival, which you liked — shares Drama; "
                + "both are from the 2020s."
        )
    }
}

enum HomeDecisionTestFixtures {
    static func snapshot(
        recommendations: [PersistedDecisionRecommendation]? = nil,
        savedMovieIDs: Set<Int> = []
    ) throws -> ThreeForTonightSnapshot {
        let signature = try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
        let items = try recommendations ?? [recommendation()]
        let cycleID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let decisionSetID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let cycle = try DecisionCycle(
            id: cycleID,
            identitySignature: signature,
            shownMovieIDs: Set(items.map(\.display.movieID))
        )
        let set = try PersistedDecisionSet(
            id: decisionSetID,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engineModelVersion: .p1Model,
            cycle: cycle,
            sourceViewerStateSnapshotID: ViewerStateSnapshotID(rawValue: decisionSetID),
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: items
        )
        return ThreeForTonightSnapshot(
            decisionSet: set,
            savedMovieIDs: savedMovieIDs
        )
    }

    static func recommendation(
        movieID: Int = 101,
        role: DecisionRole = .safeChoice,
        watchlistWrapped: Bool = true,
        reaction: PositiveAnchorReaction = .loved,
        sharedGenreIDs: Set<Int> = [18, 878],
        eraMatch: RecommendationEraMatch? = nil
    ) throws -> PersistedDecisionRecommendation {
        let drama = DecisionGenre(id: 18, name: "Drama")
        let scienceFiction = DecisionGenre(id: 878, name: "Science Fiction")
        let comedy = DecisionGenre(id: 35, name: "Comedy")
        let genres = [drama, scienceFiction]
        let sharedGenres = genres.filter { sharedGenreIDs.contains($0.id) }
        let anchorGenres = sharedGenres.count == genres.count
            ? genres
            : sharedGenres + [comedy]
        let anchor = PositiveAnchorEvidence(
            movieID: 201,
            movieTitle: "Arrival",
            reaction: reaction,
            anchorGenres: anchorGenres,
            sharedGenres: sharedGenres,
            eraMatch: eraMatch
        )
        let primary: RecommendationPrimaryEvidence = watchlistWrapped
            ? .watchlistIntent(match: .positiveAnchor(anchor))
            : .positiveAnchor(anchor)
        return try PersistedDecisionRecommendation(
            role: role,
            evidence: RecommendationEvidence(
                primary: primary,
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: movieID,
                localizedTitle: "Tonight's Movie",
                posterPath: "/poster.jpg",
                backdropPath: nil,
                runtimeMinutes: 123,
                releaseYear: 2024,
                genres: genres
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [
                    DecisionProviderSnapshot(
                        providerID: PilotStreamingService.netflix.providerID,
                        name: PilotStreamingService.netflix.name,
                        logoPath: "/netflix.jpg",
                        productOrder: PilotStreamingService.netflix.productOrder
                    ),
                ],
                verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                regionalWatchURL: URL(string: "https://www.themoviedb.org/movie/101/watch")
            )
        )
    }
}
