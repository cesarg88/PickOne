import Foundation

struct CalibrationCatalogDocumentDTO: Decodable, Sendable {
    let schemaVersion: Int
    let catalogID: String
    let version: Int
    let region: String
    let locale: String
    let updatedAt: String
    let movies: [CalibrationCatalogMovieDTO]
}

struct CalibrationCatalogMovieDTO: Decodable, Sendable {
    let order: Int
    let block: String
    let tmdbMovieID: Int
    let titleKnownInSpain: String
    let originalOrEnglishTitle: String
    let year: Int
    let originalLanguage: String
}

private struct CalibrationCatalogDocumentHeaderDTO: Decodable {
    let schemaVersion: Int
}

enum CalibrationCatalogDocumentError: Error, Equatable, Sendable {
    case responseTooLarge
    case incompatible
    case invalid
}

struct CalibrationCatalogDocument: Equatable, Sendable {
    let data: Data
    let snapshot: CalibrationCatalogSnapshot
}

struct CalibrationCatalogDocumentDecoder: Sendable {
    static let maximumResponseBytes = 64 * 1024

    func decode(
        _ data: Data,
        expectedRegion: String,
        expectedLocale: String
    ) throws -> CalibrationCatalogDocument {
        guard data.count <= Self.maximumResponseBytes else {
            throw CalibrationCatalogDocumentError.responseTooLarge
        }

        let decoder = JSONDecoder()
        let header: CalibrationCatalogDocumentHeaderDTO
        do {
            header = try decoder.decode(CalibrationCatalogDocumentHeaderDTO.self, from: data)
        } catch {
            throw CalibrationCatalogDocumentError.invalid
        }
        guard header.schemaVersion == CalibrationCatalogValidator.supportedSchemaVersion else {
            throw CalibrationCatalogDocumentError.incompatible
        }

        let dto: CalibrationCatalogDocumentDTO
        do {
            dto = try decoder.decode(CalibrationCatalogDocumentDTO.self, from: data)
        } catch {
            throw CalibrationCatalogDocumentError.invalid
        }
        guard Set(dto.movies.map(\.order)) == Set(0 ..< dto.movies.count) else {
            throw CalibrationCatalogDocumentError.invalid
        }

        let updatedAt: Date
        if let date = ISO8601DateFormatter().date(from: dto.updatedAt) {
            updatedAt = date
        } else {
            throw CalibrationCatalogDocumentError.invalid
        }

        let movies: [CalibrationMovie]
        do {
            movies = try dto.movies.sorted { $0.order < $1.order }.map { movie in
                guard let block = CalibrationCatalogBlock(rawValue: movie.block) else {
                    throw CalibrationCatalogDocumentError.invalid
                }
                return CalibrationMovie(
                    id: movie.tmdbMovieID,
                    titleKnownInSpain: movie.titleKnownInSpain,
                    originalOrEnglishTitle: movie.originalOrEnglishTitle,
                    year: movie.year,
                    originalLanguage: movie.originalLanguage,
                    block: block
                )
            }
        } catch {
            throw CalibrationCatalogDocumentError.invalid
        }

        let snapshot = CalibrationCatalogSnapshot(
            reference: CalibrationCatalogReference(
                schemaVersion: dto.schemaVersion,
                catalogID: dto.catalogID,
                version: dto.version,
                region: dto.region,
                locale: dto.locale
            ),
            movies: movies,
            updatedAt: updatedAt
        )
        do {
            try CalibrationCatalogValidator.validate(
                snapshot,
                expectedRegion: expectedRegion,
                expectedLocale: expectedLocale
            )
        } catch {
            throw CalibrationCatalogDocumentError.invalid
        }
        return CalibrationCatalogDocument(data: data, snapshot: snapshot)
    }
}
