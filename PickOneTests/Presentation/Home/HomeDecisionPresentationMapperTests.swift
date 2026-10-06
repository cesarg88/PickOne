import Foundation
@testable import PickOne
import Testing

@MainActor
struct HomeDecisionPresentationMapperTests {
    @Test("an explicit language bundle resolves strings independently of device language")
    func languageBundleResolution() throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en", withExtension: "lproj"))
        let spanishURL = try #require(Bundle.main.url(forResource: "es", withExtension: "lproj"))
        let englishBundle = try #require(Bundle(url: englishURL))
        let spanishBundle = try #require(Bundle(url: spanishURL))
        let english = String(
            localized: "Safe Choice", bundle: englishBundle, locale: MovieContentLocale.english.locale
        )
        let spanish = String(
            localized: "Safe Choice", bundle: spanishBundle, locale: MovieContentLocale.spanish.locale
        )
        #expect(english == "Safe Choice")
        #expect(spanish == "Apuesta segura")
    }

    @Test(arguments: ["en_US", "es_ES", "de_DE", "fr_FR", "ar_EG", "hi_IN"], [false, true])
    func decadeYearsNeverUseLocaleDependentNumberFormatting(localeID: String, adjacent: Bool) throws {
        let candidate = DecisionDecade(year: 2024)
        let anchor = DecisionDecade(year: 2015)
        let recommendation = try HomeDecisionTestFixtures.recommendation(
            watchlistWrapped: false,
            sharedGenreIDs: [18],
            eraMatch: adjacent ? .adjacentDecade(candidate: candidate, anchor: anchor) : .sameDecade(candidate)
        )
        let snapshot = try HomeDecisionTestFixtures.snapshot(recommendations: [recommendation])
        let item = try #require(HomeDecisionPresentationMapper.map(
            snapshot: snapshot,
            locale: Locale(identifier: localeID),
            projection: englishProjection
        ).items.first)
        #expect(item.reason.contains("2020"))
        if adjacent { #expect(item.reason.contains("2010")) }
    }

    @Test("maps role, evidence, providers, metadata, and transient saved state")
    func mapsRecommendation() throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot(savedMovieIDs: [101])

        let model = HomeDecisionPresentationMapper.map(
            snapshot: snapshot,
            locale: MovieContentLocale.english.locale,
            projection: englishProjection
        )

        let item = try #require(model.items.first)
        #expect(item.id == 101)
        #expect(item.decisionRole == .safeChoice)
        #expect(item.role == "Safe Choice")
        #expect(item.reason.contains("Arrival"))
        #expect(item.reason.contains("Drama"))
        #expect(item.reason.contains("Science Fiction"))
        #expect(item.providers.map(\.name) == ["Netflix"])
        #expect(item.details.contains("2024"))
        #expect(item.details.contains("Drama and Science Fiction"))
        #expect(item.details.contains(expectedRuntime(minutes: 123, locale: .english)))
        #expect(item.isSaved)
        #expect(try item.feedbackMetadata == MovieFeedbackMetadata(
            title: "Tonight's Movie",
            releaseYear: 2024,
            posterPath: "/poster.jpg"
        ))
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
            snapshot: snapshot,
            locale: MovieContentLocale.english.locale,
            projection: englishProjection
        ).items.first)

        #expect(item.reason.contains("Arrival"))
        #expect(item.reason.contains("Drama"))
        #expect(!item.reason.contains("2020s"))
        #expect(!item.reason.contains("Science Fiction"))
    }

    @Test("display mapper preserves artwork paths and stable roles by movie ID")
    func mapsArtworkAndRoles() throws {
        let recommendations = try [
            HomeDecisionTestFixtures.recommendation(movieID: 101, role: .safeChoice, backdropPath: "/bright.jpg"),
            HomeDecisionTestFixtures.recommendation(movieID: 202, role: .stretchChoice),
            HomeDecisionTestFixtures.recommendation(movieID: 303, role: .discoveryChoice),
        ]
        let snapshot = try HomeDecisionTestFixtures.snapshot(recommendations: recommendations)

        let items = HomeDecisionPresentationMapper.map(
            snapshot: snapshot, projection: englishProjection
        ).items

        #expect(items.map(\.id) == [101, 202, 303])
        #expect(items.map(\.decisionRole) == [.safeChoice, .stretchChoice, .discoveryChoice])
        #expect(items.first(where: { $0.id == 101 })?.backdropURL?.absoluteString.contains("bright.jpg") == true)
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
            snapshot: snapshot,
            locale: MovieContentLocale.english.locale,
            projection: englishProjection
        ).items.first)

        #expect(item.reason.contains("Arrival"))
        #expect(item.reason.contains("Drama"))
        #expect(item.reason.contains("2020"))
    }

    @Test("legacy offline evidence retains known title but hides unverified anchor and genre labels")
    func legacyOfflineEvidenceUsesTruthfulFallback() throws {
        let recommendations = try [
            HomeDecisionTestFixtures.unreadableRecommendation(movieID: 101),
            HomeDecisionTestFixtures.unreadableRecommendation(
                movieID: 102,
                role: .stretchChoice,
                usesAffinity: true
            ),
        ]
        let snapshot = try HomeDecisionTestFixtures.snapshot(
            recommendations: recommendations
        )

        let model = HomeDecisionPresentationMapper.map(
            snapshot: snapshot,
            locale: MovieContentLocale.english.locale
        )

        #expect(model.items.count == 2)
        #expect(model.items.allSatisfy { $0.title == "Tonight's Movie" })
        #expect(model.items.allSatisfy { $0.reason.contains("movies you liked") })
        #expect(model.items.allSatisfy { !$0.reason.contains("Arrival") && !$0.reason.contains("18") })
    }

    @Test("Spanish projection localizes titles, role, anchor, genre and explanation template")
    func spanishProjection() throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let projection = HomeMovieDisplayProjection(movies: [
            101: MovieDisplayMetadata(
                movieID: 101, title: "Película de esta noche", genreNames: [18: "Drama", 878: "Ciencia ficción"]
            ),
            201: MovieDisplayMetadata(
                movieID: 201, title: "La llegada", genreNames: [18: "Drama", 878: "Ciencia ficción"]
            ),
        ])

        let item = try #require(HomeDecisionPresentationMapper.map(
            snapshot: snapshot, locale: MovieContentLocale.spanish.locale, projection: projection
        ).items.first)

        #expect(item.title == "Película de esta noche")
        #expect(item.role == "Apuesta segura")
        #expect(item.reason.contains("La llegada"))
        #expect(item.reason.contains("Ciencia ficción"))
        #expect(!item.reason.contains("Arrival"))
        #expect(!item.reason.contains("Science Fiction"))
        #expect(item.details.contains("Ciencia ficción"))
        #expect(item.details.contains("Drama y Ciencia ficción"))
        #expect(item.details.contains(expectedRuntime(minutes: 123, locale: .spanish)))
    }

    @Test("unsupported device language uses English Home copy and metadata locale")
    func unsupportedLanguageFallsBackToEnglish() throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let item = try #require(HomeDecisionPresentationMapper.map(
            snapshot: snapshot,
            locale: Locale(identifier: "fr_FR"),
            projection: englishProjection
        ).items.first)

        #expect(item.role == "Safe Choice")
        #expect(item.reason.contains("Arrival"))
        #expect(!item.reason.contains("que te encantó"))
    }

    private var englishProjection: HomeMovieDisplayProjection {
        HomeMovieDisplayProjection(movies: [
            101: MovieDisplayMetadata(
                movieID: 101, title: "Tonight's Movie", genreNames: [18: "Drama", 878: "Science Fiction"]
            ),
            201: MovieDisplayMetadata(
                movieID: 201, title: "Arrival", genreNames: [18: "Drama", 878: "Science Fiction"]
            ),
        ])
    }

    private func expectedRuntime(minutes: Int, locale: MovieContentLocale) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale.locale
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: TimeInterval(minutes * 60)) ?? ""
    }
}

enum HomeDecisionTestFixtures {
    static func snapshot(
        recommendations: [PersistedDecisionRecommendation]? = nil,
        savedMovieIDs: Set<Int> = [],
        setID: UUID? = nil
    ) throws -> ThreeForTonightSnapshot {
        let signature = try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
        let items = try recommendations ?? [recommendation()]
        let cycleID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let decisionSetID = try #require(setID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
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
        eraMatch: RecommendationEraMatch? = nil,
        backdropPath: String? = nil
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
                backdropPath: backdropPath,
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

    static func unreadableRecommendation(
        movieID: Int,
        role: DecisionRole = .safeChoice,
        usesAffinity: Bool = false
    ) throws -> PersistedDecisionRecommendation {
        let unnamedDrama = DecisionGenre(id: 18)
        let primary: RecommendationPrimaryEvidence = usesAffinity
            ? .positiveGenreAffinity(PositiveAffinityEvidence(
                genres: [unnamedDrama],
                era: DecisionDecade(year: 2020)
            ))
            : .positiveAnchor(PositiveAnchorEvidence(
                movieID: 201,
                movieTitle: "Arrival",
                reaction: .loved,
                anchorGenres: [unnamedDrama],
                sharedGenres: [unnamedDrama],
                eraMatch: nil
            ))
        return try PersistedDecisionRecommendation.restoringLegacyEvidence(
            role: role,
            evidence: RecommendationEvidence(
                primary: primary,
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: movieID,
                localizedTitle: "Tonight's Movie",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 123,
                releaseYear: 2024,
                genres: [unnamedDrama]
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
    }
}
