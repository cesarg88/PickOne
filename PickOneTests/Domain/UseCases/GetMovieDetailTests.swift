import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("GetMovieDetail Tests", .serialized)
struct GetMovieDetailTests {
    @Test("detail ok + similar fail returns snapshot with unavailable")
    func detailOkSimilarFailReturnsUnavailableSnapshot() async throws {
        let repository = MockMovieRepository(
            detail: .success(CacheResult(value: TestFixtures.movie, isStale: false)),
            similar: .failure(.similarFailed),
            credits: .success(CacheResult(value: TestFixtures.credits, isStale: false))
        )
        
        let sut = GetMovieDetail(repository: repository)
        let result = try await sut.execute(id: 1, policy: .returnCacheElseLoad)
        
        #expect(result.value.movie.id == 1)
        #expect(result.value.similar.isEmpty == true)
        #expect(result.value.isSimilarUnavailable == true)
        #expect(result.value.isCreditsUnavailable == false)
        #expect(result.isStale == false)
    }
    
    @Test("credits fail but similar ok returns unavailable credits")
    func creditsFailSimilarOkReturnsUnavailableCredits() async throws {
        let repository = MockMovieRepository(
            detail: .success(CacheResult(value: TestFixtures.movie, isStale: false)),
            similar: .success(CacheResult(value: TestFixtures.similarPage, isStale: false)),
            credits: .failure(.creditsFailed)
        )
        
        let sut = GetMovieDetail(repository: repository)
        let result = try await sut.execute(id: 1, policy: .returnCacheElseLoad)
        
        #expect(result.value.isCreditsUnavailable == true)
        #expect(result.value.topCast.isEmpty == true)
        #expect(result.value.isSimilarUnavailable == false)
    }
    
    @Test("detail fail throws error")
    func detailFailThrows() async throws {
        let repository = MockMovieRepository(
            detail: .failure(.detailFailed),
            similar: .success(
                CacheResult(
                    value: MoviePage(page: 1, totalPages: 1, movies: []),
                    isStale: false
                )
            ),
            credits: .success(CacheResult(value: TestFixtures.credits, isStale: false))
        )
        
        let sut = GetMovieDetail(repository: repository)
        
        await #expect(throws: TestError.self) {
            _ = try await sut.execute(id: 1, policy: .returnCacheElseLoad)
        }
    }
    
    @Test("stale semantics use OR across successful results")
    func staleSemanticsUseOrAcrossResults() async throws {
        let repository = MockMovieRepository(
            detail: .success(CacheResult(value: TestFixtures.movie, isStale: false)),
            similar: .success(CacheResult(value: TestFixtures.similarPage, isStale: true)),
            credits: .success(CacheResult(value: TestFixtures.credits, isStale: false))
        )
        
        let sut = GetMovieDetail(repository: repository)
        let result = try await sut.execute(id: 1, policy: .returnCacheElseLoad)
        
        #expect(result.isStale == true)
    }
}

private enum MockResult<Value: Sendable>: Sendable {
    case success(CacheResult<Value>)
    case failure(TestError)

    func get() throws -> CacheResult<Value> {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

private struct MockMovieRepository: MovieRepository {
    let detail: MockResult<Movie>
    let similar: MockResult<MoviePage>
    let credits: MockResult<Credits>
    
    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        CacheResult(value: MoviePage(page: 1, totalPages: 1, movies: []), isStale: false)
    }
    
    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie> {
        try detail.get()
    }
    
    func getSimilarMovies(id: Int, page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        try similar.get()
    }
    
    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits> {
        try credits.get()
    }
    
    func searchMovies(query: String, page: Int) async throws -> MoviePage {
        MoviePage(page: 1, totalPages: 1, movies: [])
    }
}

private enum TestError: Error, Sendable {
    case detailFailed
    case similarFailed
    case creditsFailed
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
    
    static let similarPage = MoviePage(
        page: 1,
        totalPages: 1,
        movies: [
            MovieSummary(id: 2, title: "Movie B", posterPath: nil, releaseYear: 2022, rating: 7.4)
        ]
    )
}
