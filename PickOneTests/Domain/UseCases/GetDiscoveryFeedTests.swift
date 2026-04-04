import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("GetDiscoveryFeed Tests", .serialized)
struct GetDiscoveryFeedTests {
    @Test("maps repository page into snapshot")
    func mapsPageIntoSnapshot() async throws {
        let repository = MockMovieRepository()
        repository.topRatedResult = .success(CacheResult(value: TestFixtures.page, isStale: false))
        
        let sut = GetDiscoveryFeed(repository: repository)
        let result = try await sut.execute(page: 1, policy: .returnCacheElseLoad)
        
        #expect(result.value.currentPage == 1)
        #expect(result.value.hasMorePages == true)
        #expect(result.value.movies.count == 2)
        #expect(result.isStale == false)
    }
    
    @Test("propagates stale flag")
    func propagatesStaleFlag() async throws {
        let repository = MockMovieRepository()
        repository.topRatedResult = .success(CacheResult(value: TestFixtures.page, isStale: true))
        
        let sut = GetDiscoveryFeed(repository: repository)
        let result = try await sut.execute(page: 1, policy: .returnCacheElseLoad)
        
        #expect(result.isStale == true)
    }
    
    @Test("throws when repository fails")
    func throwsWhenRepositoryFails() async throws {
        let repository = MockMovieRepository()
        repository.topRatedResult = .failure(TestError.fetchFailed)
        
        let sut = GetDiscoveryFeed(repository: repository)
        
        await #expect(throws: TestError.self) {
            _ = try await sut.execute(page: 1, policy: .returnCacheElseLoad)
        }
    }
}

private final class MockMovieRepository: MovieRepository, @unchecked Sendable {
    var topRatedResult: Result<CacheResult<MoviePage>, Error> = .success(CacheResult(value: TestFixtures.page, isStale: false))
    
    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        try topRatedResult.get()
    }
    
    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie> {
        CacheResult(value: TestFixtures.movie, isStale: false)
    }
    
    func getSimilarMovies(id: Int, page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        CacheResult(value: TestFixtures.page, isStale: false)
    }
    
    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits> {
        CacheResult(value: TestFixtures.credits, isStale: false)
    }
    
    func searchMovies(query: String, page: Int) async throws -> MoviePage {
        TestFixtures.page
    }
}

private enum TestError: Error {
    case fetchFailed
}

private enum TestFixtures {
    static let movie = Movie(
        id: 1,
        title: "Movie A",
        originalTitle: "Movie A",
        overview: "Overview",
        releaseDate: nil,
        runtime: 120,
        rating: 8.0,
        voteCount: 100,
        posterPath: nil,
        backdropPath: nil,
        genres: [],
        tagline: nil
    )
    
    static let credits = Credits(
        director: Person(id: 10, name: "Director", profilePath: nil, role: .director),
        topCast: [
            Person(id: 11, name: "Actor", profilePath: nil, role: .cast(character: "Hero"))
        ]
    )
    
    static let page = MoviePage(
        page: 1,
        totalPages: 3,
        movies: [
            MovieSummary(id: 1, title: "Movie A", posterPath: nil, releaseYear: 2023, rating: 8.1),
            MovieSummary(id: 2, title: "Movie B", posterPath: nil, releaseYear: 2022, rating: 7.4)
        ]
    )
}
