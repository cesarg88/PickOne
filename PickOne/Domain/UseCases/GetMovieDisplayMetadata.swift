import Foundation

protocol GetMovieDisplayMetadataUseCase: Sendable {
    func execute(movieID: Int, contentLocale: MovieContentLocale) async throws -> MovieDisplayMetadata
}

struct GetMovieDisplayMetadata: GetMovieDisplayMetadataUseCase {
    let repository: any MovieRepository

    func execute(movieID: Int, contentLocale: MovieContentLocale) async throws -> MovieDisplayMetadata {
        let cached = try await repository.getMovieDetail(
            id: movieID,
            contentLocale: contentLocale,
            policy: .returnCacheElseLoad
        )
        try Task.checkCancellation()
        guard cached.isStale else {
            return try metadata(from: cached.value, movieID: movieID)
        }
        do {
            let refreshed = try await repository.getMovieDetail(
                id: movieID,
                contentLocale: contentLocale,
                policy: .refresh
            )
            try Task.checkCancellation()
            return try metadata(from: refreshed.value, movieID: movieID)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return try metadata(from: cached.value, movieID: movieID)
        }
    }

    private func metadata(from movie: Movie, movieID: Int) throws -> MovieDisplayMetadata {
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
