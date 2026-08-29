@testable import PickOne
import Testing

@Suite("Calibration catalog validation")
struct CalibrationCatalogValidationTests {
    @Test("the approved bundled snapshot satisfies every invariant")
    func approvedSnapshotIsValid() throws {
        let snapshot = CalibrationCatalogTestFixtures.snapshot()

        try CalibrationCatalogValidator.validate(
            snapshot,
            expectedRegion: CalibrationCatalogTestFixtures.region,
            expectedLocale: CalibrationCatalogTestFixtures.locale
        )

        #expect(snapshot.catalog == .spainHouseholdV1)
    }

    @Test("reference invariants are enforced")
    func referenceInvariants() {
        expectValidationError(.unsupportedSchema, snapshot: .init(
            schemaVersion: 2
        ))
        expectValidationError(.emptyCatalogID, snapshot: .init(
            catalogID: "  "
        ))
        expectValidationError(.invalidVersion, snapshot: .init(
            version: 0
        ))
        expectValidationError(.unsupportedRegion, snapshot: .init(
            region: "US"
        ))
        expectValidationError(.unsupportedLocale, snapshot: .init(
            locale: "en-US"
        ))
    }

    @Test("movie identity, count, and block invariants are enforced")
    func movieStructureInvariants() {
        expectValidationError(.emptyCatalog, snapshot: .init(movies: []))

        let tooMany = (0 ... CalibrationCatalogValidator.maximumMovieCount).map { index in
            CalibrationMovie(
                id: index + 1,
                titleKnownInSpain: "Movie \(index)",
                originalOrEnglishTitle: "Movie \(index)",
                year: 2000,
                originalLanguage: index == 0 ? "es" : "en",
                block: .primary
            )
        }
        expectValidationError(.tooManyMovies, snapshot: .init(movies: tooMany))

        var movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(movies[0], id: 0)
        expectValidationError(.invalidMovieID, snapshot: .init(movies: movies))

        movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[1] = CalibrationCatalogTestFixtures.replacing(movies[1], id: movies[0].id)
        expectValidationError(.duplicateMovieID, snapshot: .init(movies: movies))

        movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(movies[0], block: .reserve)
        expectValidationError(.invalidBlockCount, snapshot: .init(movies: movies))
    }

    @Test("movie fallback metadata and early diversity are enforced")
    func movieMetadataInvariants() {
        var movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(movies[0], localizedTitle: " ")
        expectValidationError(.emptyLocalizedTitle, snapshot: .init(movies: movies))

        movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(movies[0], fallbackTitle: "")
        expectValidationError(.emptyFallbackTitle, snapshot: .init(movies: movies))

        movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(movies[0], year: 999)
        expectValidationError(.invalidYear, snapshot: .init(movies: movies))

        movies = CalibrationCatalog.spainHouseholdV1.movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(movies[0], language: " ")
        expectValidationError(.emptyLanguage, snapshot: .init(movies: movies))

        movies = CalibrationCatalog.spainHouseholdV1.movies.enumerated().map { index, movie in
            index < 8
                ? CalibrationCatalogTestFixtures.replacing(movie, language: "en")
                : movie
        }
        expectValidationError(.insufficientEarlyDiversity, snapshot: .init(movies: movies))
    }

    private func expectValidationError(
        _ expected: CalibrationCatalogValidationError,
        snapshot: CalibrationCatalogSnapshot
    ) {
        #expect(throws: expected) {
            try CalibrationCatalogValidator.validate(
                snapshot,
                expectedRegion: CalibrationCatalogTestFixtures.region,
                expectedLocale: CalibrationCatalogTestFixtures.locale
            )
        }
    }
}

private extension CalibrationCatalogSnapshot {
    init(
        schemaVersion: Int = 1,
        catalogID: String = "es-household-calibration",
        version: Int = 1,
        region: String = CalibrationCatalogTestFixtures.region,
        locale: String = CalibrationCatalogTestFixtures.locale,
        movies: [CalibrationMovie] = CalibrationCatalog.spainHouseholdV1.movies
    ) {
        self = CalibrationCatalogTestFixtures.snapshot(
            schemaVersion: schemaVersion,
            catalogID: catalogID,
            version: version,
            region: region,
            locale: locale,
            movies: movies
        )
    }
}
