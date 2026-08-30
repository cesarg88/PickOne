import Foundation

struct CalibrationCatalogReference: Equatable, Sendable {
    let schemaVersion: Int
    let catalogID: String
    let version: Int
    let region: String
    let locale: String

    var viewerProfileCatalogID: CalibrationCatalogID {
        CalibrationCatalogID(rawValue: "\(catalogID)-v\(version)")
    }
}

struct CalibrationCatalogSnapshot: Equatable, Sendable {
    let reference: CalibrationCatalogReference
    let movies: [CalibrationMovie]
    let updatedAt: Date

    var catalog: CalibrationCatalog {
        CalibrationCatalog(
            id: reference.viewerProfileCatalogID,
            movies: movies
        )
    }
}

enum CalibrationCatalogResolutionSource: Equatable, Sendable {
    case remote
    case cached
    case bundled
}

enum CalibrationCatalogRemoteFailure: Equatable, Sendable {
    case absent
    case invalid
    case incompatible
    case unavailable
}

struct CalibrationCatalogResolution: Equatable, Sendable {
    let snapshot: CalibrationCatalogSnapshot
    let source: CalibrationCatalogResolutionSource
    let remoteFailure: CalibrationCatalogRemoteFailure?
    let cacheWriteFailed: Bool
}

enum CalibrationCatalogResolutionError: Error, Equatable, Sendable {
    case invalidBundledCatalog
}

enum CalibrationCatalogValidationError: Error, Equatable, Sendable {
    case unsupportedSchema
    case emptyCatalogID
    case invalidVersion
    case unsupportedRegion
    case unsupportedLocale
    case emptyCatalog
    case tooManyMovies
    case invalidMovieID
    case duplicateMovieID
    case invalidBlockCount
    case emptyLocalizedTitle
    case emptyFallbackTitle
    case invalidYear
    case emptyLanguage
    case insufficientEarlyDiversity
}

enum CalibrationCatalogValidator {
    static let supportedSchemaVersion = 1
    static let maximumMovieCount = 64
    static let primaryCount = 12
    static let reserveCount = 3
    static let optionalExtensionCount = 6

    static func validate(
        _ snapshot: CalibrationCatalogSnapshot,
        expectedRegion: String,
        expectedLocale: String
    ) throws {
        let reference = snapshot.reference
        guard reference.schemaVersion == supportedSchemaVersion else {
            throw CalibrationCatalogValidationError.unsupportedSchema
        }
        guard !reference.catalogID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CalibrationCatalogValidationError.emptyCatalogID
        }
        guard reference.version > 0 else {
            throw CalibrationCatalogValidationError.invalidVersion
        }
        guard reference.region == expectedRegion else {
            throw CalibrationCatalogValidationError.unsupportedRegion
        }
        guard reference.locale == expectedLocale else {
            throw CalibrationCatalogValidationError.unsupportedLocale
        }
        guard !snapshot.movies.isEmpty else {
            throw CalibrationCatalogValidationError.emptyCatalog
        }
        guard snapshot.movies.count <= maximumMovieCount else {
            throw CalibrationCatalogValidationError.tooManyMovies
        }
        guard snapshot.movies.allSatisfy({ $0.id > 0 }) else {
            throw CalibrationCatalogValidationError.invalidMovieID
        }
        guard Set(snapshot.movies.map(\.id)).count == snapshot.movies.count else {
            throw CalibrationCatalogValidationError.duplicateMovieID
        }
        try validateBlocks(snapshot.movies)
        try validateMetadata(snapshot.movies)
        guard snapshot.movies.prefix(8).contains(where: { $0.originalLanguage != "en" }) else {
            throw CalibrationCatalogValidationError.insufficientEarlyDiversity
        }
    }

    private static func validateBlocks(_ movies: [CalibrationMovie]) throws {
        let expectedBlocks =
            Array(repeating: CalibrationCatalogBlock.primary, count: primaryCount) +
            Array(repeating: CalibrationCatalogBlock.reserve, count: reserveCount) +
            Array(
                repeating: CalibrationCatalogBlock.optionalExtension,
                count: optionalExtensionCount
            )
        guard movies.map(\.block) == expectedBlocks else {
            throw CalibrationCatalogValidationError.invalidBlockCount
        }
    }

    private static func validateMetadata(_ movies: [CalibrationMovie]) throws {
        guard movies.allSatisfy({
            !$0.titleKnownInSpain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw CalibrationCatalogValidationError.emptyLocalizedTitle
        }
        guard movies.allSatisfy({
            !$0.originalOrEnglishTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw CalibrationCatalogValidationError.emptyFallbackTitle
        }
        guard movies.allSatisfy({ (1888 ... 2100).contains($0.year) }) else {
            throw CalibrationCatalogValidationError.invalidYear
        }
        guard movies.allSatisfy({
            !$0.originalLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw CalibrationCatalogValidationError.emptyLanguage
        }
    }
}
