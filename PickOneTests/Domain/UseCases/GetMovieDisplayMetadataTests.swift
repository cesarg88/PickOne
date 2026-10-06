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

    @Test("stale localized metadata is replaced by a successful refresh")
    func refreshesStaleMetadata() async throws {
        let cached = movie(title: "Old title", genreName: "Old genre")
        let refreshed = movie(title: "New title", genreName: "New genre")
        let sut = GetMovieDisplayMetadata(repository: DisplayMovieRepository(
            movie: cached, isStale: true, refreshedMovie: refreshed
        ))

        let metadata = try await sut.execute(movieID: 12, contentLocale: .spanish)

        #expect(metadata.title == "New title")
        #expect(metadata.genreNames[18] == "New genre")
    }

    @Test("stale matching-locale metadata survives a failed refresh")
    func retainsStaleMetadataOffline() async throws {
        let cached = movie(title: "Cached title", genreName: "Cached genre")
        let sut = GetMovieDisplayMetadata(repository: DisplayMovieRepository(
            movie: cached, isStale: true, refreshFails: true
        ))

        let metadata = try await sut.execute(movieID: 12, contentLocale: .spanish)

        #expect(metadata.title == "Cached title")
        #expect(metadata.genreNames[18] == "Cached genre")
    }

    @Test("invalid refreshed metadata retains the valid cached value")
    func retainsStaleMetadataAfterInvalidRefresh() async throws {
        let cached = movie(title: "Cached title", genreName: "Cached genre")
        let invalid = Movie(
            id: 99, title: "Wrong movie", originalTitle: "Wrong movie", overview: "",
            releaseDate: nil, runtime: nil, rating: 0, voteCount: 0,
            posterPath: nil, backdropPath: nil, genres: [], tagline: nil
        )
        let sut = GetMovieDisplayMetadata(repository: DisplayMovieRepository(
            movie: cached, isStale: true, refreshedMovie: invalid
        ))

        let metadata = try await sut.execute(movieID: 12, contentLocale: .english)

        #expect(metadata.title == "Cached title")
    }

    @Test("cancelled refresh does not publish stale metadata")
    func propagatesRefreshCancellation() async {
        let sut = GetMovieDisplayMetadata(repository: DisplayMovieRepository(
            movie: movie(title: "Cached title", genreName: "Drama"),
            isStale: true,
            refreshCancels: true
        ))

        await #expect(throws: CancellationError.self) {
            _ = try await sut.execute(movieID: 12, contentLocale: .english)
        }
    }

    private func movie(title: String, genreName: String) -> Movie {
        Movie(
            id: 12, title: title, originalTitle: title, overview: "",
            releaseDate: nil, runtime: nil, rating: 0, voteCount: 0,
            posterPath: nil, backdropPath: nil,
            genres: [Genre(id: 18, name: genreName)], tagline: nil
        )
    }
}

private struct DisplayMovieRepository: MovieRepository {
    let movie: Movie
    var isStale = false
    var refreshedMovie: Movie?
    var refreshFails = false
    var refreshCancels = false

    func getMovieDetail(id _: Int, policy _: CachePolicy) -> CacheResult<Movie> {
        CacheResult(value: movie, isStale: false)
    }

    func getMovieDetail(
        id _: Int,
        contentLocale _: MovieContentLocale,
        policy: CachePolicy
    ) throws -> CacheResult<Movie> {
        if policy == .refresh {
            if refreshCancels { throw CancellationError() }
            if refreshFails { throw DisplayRepositoryError.unavailable }
            return CacheResult(value: refreshedMovie ?? movie, isStale: false)
        }
        return CacheResult(value: movie, isStale: isStale)
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
    case unavailable
}
