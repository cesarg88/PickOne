@testable import PickOne
import Testing

@MainActor
@Suite("Calibration movie presentation mapper tests")
struct CalibrationMoviePresentationMapperTests {
    @Test("equivalent title forms collapse case and repeated whitespace")
    func equivalentTitles() {
        let movie = CalibrationMovie(
            id: 1,
            titleKnownInSpain: "Interstellar",
            originalOrEnglishTitle: "Interstellar",
            year: 2014,
            originalLanguage: "en",
            block: .primary
        )
        let metadata = CalibrationMovieMetadata(
            title: "  INTERSTELLAR ",
            originalTitle: "Interstellar",
            releaseYear: 2014,
            posterPath: nil
        )

        let result = CalibrationMoviePresentationMapper.map(
            catalogMovie: movie,
            metadata: metadata
        )

        #expect(result.primaryText == "INTERSTELLAR · 2014")
        #expect(result.secondaryText == nil)
    }

    @Test("distinct punctuation and diacritics remain on two lines")
    func distinctTitles() {
        let movie = CalibrationCatalog.spainHouseholdV1.movies[17]

        let result = CalibrationMoviePresentationMapper.map(
            catalogMovie: movie,
            metadata: nil
        )

        #expect(result.primaryText == "Amelie")
        #expect(result.secondaryText == "Amélie · 2001")
        #expect(CalibrationMoviePresentationMapper.normalized("A  Quiet Place") == "a quiet place")
        #expect(CalibrationMoviePresentationMapper.normalized("Amelie") != "amélie")
    }

    @Test("hydrated and fallback metadata use the same two-line rule")
    func hydratedAndFallbackRule() {
        let movie = CalibrationCatalog.spainHouseholdV1.movies[5]
        let hydrated = CalibrationMovieMetadata(
            title: "El viaje de Chihiro",
            originalTitle: "Spirited Away",
            releaseYear: 2001,
            posterPath: "/poster.jpg"
        )

        let fallbackResult = CalibrationMoviePresentationMapper.map(
            catalogMovie: movie,
            metadata: nil
        )
        let hydratedResult = CalibrationMoviePresentationMapper.map(
            catalogMovie: movie,
            metadata: hydrated
        )

        #expect(fallbackResult.primaryText == hydratedResult.primaryText)
        #expect(fallbackResult.secondaryText == hydratedResult.secondaryText)
        #expect(hydratedResult.posterURL != nil)
    }
}
