import Foundation
@testable import PickOne
import Testing

enum CalibrationCatalogTestFixtures {
    static let region = "ES"
    static let locale = "es-ES"
    static let updatedAt = Date(timeIntervalSince1970: 1_787_097_600)

    static func snapshot(
        schemaVersion: Int = 1,
        catalogID: String = "es-household-calibration",
        version: Int = 1,
        region: String = region,
        locale: String = locale,
        movies: [CalibrationMovie] = CalibrationCatalog.spainHouseholdV1.movies
    ) -> CalibrationCatalogSnapshot {
        CalibrationCatalogSnapshot(
            reference: CalibrationCatalogReference(
                schemaVersion: schemaVersion,
                catalogID: catalogID,
                version: version,
                region: region,
                locale: locale
            ),
            movies: movies,
            updatedAt: updatedAt
        )
    }

    static func resourceURL() throws -> URL {
        try #require(
            Bundle.main.url(
                forResource: "calibration-catalog-es-ES-v1",
                withExtension: "json"
            )
        )
    }

    static func documentData() throws -> Data {
        try Data(contentsOf: resourceURL())
    }

    static func document() throws -> CalibrationCatalogDocument {
        try CalibrationCatalogDocumentDecoder().decode(
            documentData(),
            expectedRegion: region,
            expectedLocale: locale
        )
    }

    static func replacing(
        _ movie: CalibrationMovie,
        id: Int? = nil,
        localizedTitle: String? = nil,
        fallbackTitle: String? = nil,
        year: Int? = nil,
        language: String? = nil,
        block: CalibrationCatalogBlock? = nil
    ) -> CalibrationMovie {
        CalibrationMovie(
            id: id ?? movie.id,
            titleKnownInSpain: localizedTitle ?? movie.titleKnownInSpain,
            originalOrEnglishTitle: fallbackTitle ?? movie.originalOrEnglishTitle,
            year: year ?? movie.year,
            originalLanguage: language ?? movie.originalLanguage,
            block: block ?? movie.block
        )
    }
}
