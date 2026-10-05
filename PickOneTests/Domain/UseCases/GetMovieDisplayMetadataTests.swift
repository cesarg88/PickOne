import Foundation
@testable import PickOne
import Testing

@Suite("Movie display metadata")
struct GetMovieDisplayMetadataTests {
    @Test("effective content locale accepts Spanish variants and falls back to English")
    func mapsEffectiveLocale() {
        #expect(MovieContentLocale(effectiveLocale: Locale(identifier: "es_ES")) == .spanish)
        #expect(MovieContentLocale(effectiveLocale: Locale(identifier: "en_GB")) == .english)
        #expect(MovieContentLocale(effectiveLocale: Locale(identifier: "fr_FR")) == .english)
    }

    @Test("duplicate and malformed remote genre labels cannot trap or appear in display metadata")
    func validatesGenreLabels() async throws {
        let movie = Movie(
            id: 12,
            title: "Localized title",
            originalTitle: "Original title",
            overview: "",
            releaseDate: nil,
            runtime: nil,
            rating: 0,
            voteCount: 0,
            posterPath: nil,
            backdropPath: nil,
            genres: [
                Genre(id: 18, name: "Drama"),
                Genre(id: 18, name: "Unexpected duplicate"),
                Genre(id: -1, name: "Invalid ID"),
                Genre(id: 35, name: "   "),
            ],
            tagline: nil
        )
        let sut = GetMovieDisplayMetadata(repository: DisplayMovieRepository(movie: movie))

        let metadata = try await sut.execute(movieID: 12, contentLocale: .spanish)

        #expect(metadata.genreNames == [18: "Drama"])
    }

    @Test("mismatched movie identity is rejected")
    func rejectsMismatchedMovie() async {
        let movie = Movie(
            id: 99, title: "Wrong movie", originalTitle: "Wrong movie", overview: "",
            releaseDate: nil, runtime: nil, rating: 0, voteCount: 0,
            posterPath: nil, backdropPath: nil, genres: [], tagline: nil
        )
        let sut = GetMovieDisplayMetadata(repository: DisplayMovieRepository(movie: movie))

        await #expect(throws: MovieDisplayMetadataError.self) {
            _ = try await sut.execute(movieID: 12, contentLocale: .english)
        }
    }
}

private struct DisplayMovieRepository: MovieRepository {
    let movie: Movie

    func getMovieDetail(id _: Int, policy _: CachePolicy) -> CacheResult<Movie> {
        CacheResult(value: movie, isStale: false)
    }

    func getMovieDetail(
        id _: Int,
        contentLocale _: MovieContentLocale,
        policy _: CachePolicy
    ) -> CacheResult<Movie> {
        CacheResult(value: movie, isStale: false)
    }

    func getTopRated(page _: Int, policy _: CachePolicy) throws -> CacheResult<MoviePage> {
        throw DisplayRepositoryError.unused
    }

    func getSimilarMovies(id _: Int, page _: Int, policy _: CachePolicy) throws -> CacheResult<MoviePage> {
        throw DisplayRepositoryError.unused
    }

    func getCredits(id _: Int, policy _: CachePolicy) throws -> CacheResult<Credits> {
        throw DisplayRepositoryError.unused
    }

    func searchMovies(query _: String, page _: Int) throws -> MoviePage {
        throw DisplayRepositoryError.unused
    }
}

private enum DisplayRepositoryError: Error {
    case unused
}
