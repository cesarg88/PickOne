import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("MovieDetailViewModel Tests", .serialized)
struct MovieDetailViewModelTests {
    @Test("load sets loaded state")
    func loadSetsLoadedState() async throws {
        let useCase = MockGetMovieDetailUseCase()
        useCase.results = [
            .success(CacheResult(value: TestFixtures.snapshot, isStale: false))
        ]
        
        let sut = MovieDetailViewModel(movieId: 1, getMovieDetail: useCase)
        await sut.load()
        
        guard case .loaded(let data) = sut.state else {
            #expect(false, "Expected loaded state")
            return
        }
        
        #expect(data.title == "Movie A")
        #expect(data.similar.count == 1)
    }
    
    @Test("stale refresh overrides loaded state")
    func staleRefreshOverridesLoadedState() async throws {
        let useCase = MockGetMovieDetailUseCase()
        useCase.results = [
            .success(CacheResult(value: TestFixtures.snapshot, isStale: true)),
            .success(CacheResult(value: TestFixtures.refreshedSnapshot, isStale: false))
        ]
        
        let sut = MovieDetailViewModel(movieId: 1, getMovieDetail: useCase)
        await sut.load()
        
        guard case .loaded(let data) = sut.state else {
            #expect(false, "Expected loaded state")
            return
        }
        
        #expect(data.title == "Movie B")
    }
    
    @Test("load error sets error state")
    func loadErrorSetsErrorState() async throws {
        let useCase = MockGetMovieDetailUseCase()
        useCase.results = [
            .failure(TestError.fetchFailed)
        ]
        
        let sut = MovieDetailViewModel(movieId: 1, getMovieDetail: useCase)
        await sut.load()
        
        guard case .error = sut.state else {
            #expect(false, "Expected error state")
            return
        }
    }
}

@MainActor
private final class MockGetMovieDetailUseCase: GetMovieDetailUseCase {
    var results: [Result<CacheResult<MovieDetailSnapshot>, Error>] = []
    private var callIndex = 0
    
    func execute(id: Int, policy: CachePolicy) async throws -> CacheResult<MovieDetailSnapshot> {
        defer { callIndex += 1 }
        return try results[callIndex].get()
    }
}

private enum TestError: Error {
    case fetchFailed
}

private enum TestFixtures {
    static let snapshot = MovieDetailSnapshot(
        movie: Movie(
            id: 1,
            title: "Movie A",
            originalTitle: "Movie A",
            overview: "Overview",
            releaseDate: nil,
            runtime: 120,
            rating: 8.0,
            voteCount: 100,
            posterPath: "/posterA.jpg",
            backdropPath: "/backdropA.jpg",
            genres: [],
            tagline: nil
        ),
        similar: [
            MovieSummary(id: 2, title: "Movie B", posterPath: "/posterB.jpg", releaseYear: 2022, rating: 7.4)
        ],
        isInWatchlist: false,
        isWatched: false,
        director: Person(id: 10, name: "Director", profilePath: nil, role: .director),
        topCast: [Person(id: 11, name: "Actor", profilePath: nil, role: .cast(character: "Hero"))],
        isSimilarUnavailable: false,
        isCreditsUnavailable: false,
        asOf: Date()
    )
    
    static let refreshedSnapshot = MovieDetailSnapshot(
        movie: Movie(
            id: 1,
            title: "Movie B",
            originalTitle: "Movie B",
            overview: "Overview",
            releaseDate: nil,
            runtime: 121,
            rating: 8.2,
            voteCount: 110,
            posterPath: "/posterB.jpg",
            backdropPath: "/backdropB.jpg",
            genres: [],
            tagline: nil
        ),
        similar: [],
        isInWatchlist: false,
        isWatched: false,
        director: nil,
        topCast: [],
        isSimilarUnavailable: true,
        isCreditsUnavailable: true,
        asOf: Date()
    )
}
