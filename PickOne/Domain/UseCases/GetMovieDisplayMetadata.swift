import Foundation

protocol GetMovieDisplayMetadataUseCase: Sendable {
    func execute(movieID: Int, contentLocale: MovieContentLocale) async throws -> MovieDisplayMetadata
}

struct GetMovieDisplayMetadata: GetMovieDisplayMetadataUseCase {
    let repository: any MovieRepository

    func execute(movieID: Int, contentLocale: MovieContentLocale) async throws -> MovieDisplayMetadata {
        let movie = try await repository.getMovieDetail(
            id: movieID,
            contentLocale: contentLocale,
            policy: .returnCacheElseLoad
        ).value
        let title = movie.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard movie.id == movieID, !title.isEmpty else {
            throw MovieDisplayMetadataError.invalidMovie
        }
        let genreNames = movie.genres.reduce(into: [Int: String]()) { names, genre in
            let name = genre.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if genre.id > 0, !name.isEmpty, names[genre.id] == nil {
                names[genre.id] = name
            }
        }
        return MovieDisplayMetadata(movieID: movieID, title: title, genreNames: genreNames)
    }
}

enum MovieDisplayMetadataError: Error {
    case invalidMovie
}
