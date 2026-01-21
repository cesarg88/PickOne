import Testing
import Foundation
@testable import PickOne

@MainActor
@Suite("DiscoveryViewModel Tests", .serialized)
struct DiscoveryViewModelTests {
    @Test("loadInitial maps and sets loaded state")
    func loadInitialMapsAndSetsLoadedState() async throws {
        let useCase = MockGetDiscoveryFeedUseCase()
        useCase.results = [
            .success(CacheResult(value: TestFixtures.snapshotPage1, isStale: false))
        ]
        
        let sut = DiscoveryViewModel(getDiscoveryFeed: useCase)
        await sut.loadInitial()
        
        guard case .loaded(let data) = sut.state else {
            #expect(false, "Expected loaded state")
            return
        }
        
        #expect(data.currentPage == 1)
        #expect(data.hasMorePages == true)
        #expect(data.movies.count == 2)
        #expect(data.movies[0].title == "Movie A")
    }
    
    @Test("loadInitial error sets error state")
    func loadInitialErrorSetsErrorState() async throws {
        let useCase = MockGetDiscoveryFeedUseCase()
        useCase.results = [
            .failure(TestError.fetchFailed)
        ]
        
        let sut = DiscoveryViewModel(getDiscoveryFeed: useCase)
        await sut.loadInitial()
        
        guard case .error = sut.state else {
            #expect(false, "Expected error state")
            return
        }
    }
    
    @Test("loadNextPageIfNeeded appends results")
    func loadNextPageAppendsResults() async throws {
        let useCase = MockGetDiscoveryFeedUseCase()
        useCase.results = [
            .success(CacheResult(value: TestFixtures.snapshotPage1, isStale: false)),
            .success(CacheResult(value: TestFixtures.snapshotPage2, isStale: false))
        ]
        
        let sut = DiscoveryViewModel(getDiscoveryFeed: useCase)
        await sut.loadInitial()
        
        guard case .loaded(let initial) = sut.state else {
            #expect(false, "Expected loaded state")
            return
        }
        
        let lastMovie = initial.movies.last!
        await sut.loadNextPageIfNeeded(current: lastMovie)
        
        guard case .loaded(let appended) = sut.state else {
            #expect(false, "Expected loaded state after append")
            return
        }
        
        #expect(appended.currentPage == 2)
        #expect(appended.movies.count == 3)
        #expect(appended.movies.last?.title == "Movie C")
    }
}

@MainActor
private final class MockGetDiscoveryFeedUseCase: GetDiscoveryFeedUseCase {
    var results: [Result<CacheResult<DiscoverySnapshot>, Error>] = []
    private var callIndex = 0
    
    func execute(page: Int, policy: CachePolicy) async throws -> CacheResult<DiscoverySnapshot> {
        defer { callIndex += 1 }
        return try results[callIndex].get()
    }
}

private enum TestError: Error {
    case fetchFailed
}

private enum TestFixtures {
    static let snapshotPage1 = DiscoverySnapshot(
        movies: [
            MovieSummary(id: 1, title: "Movie A", posterPath: "/posterA.jpg", releaseYear: 2023, rating: 8.1),
            MovieSummary(id: 2, title: "Movie B", posterPath: "/posterB.jpg", releaseYear: 2022, rating: 7.4)
        ],
        currentPage: 1,
        hasMorePages: true,
        asOf: Date()
    )
    
    static let snapshotPage2 = DiscoverySnapshot(
        movies: [
            MovieSummary(id: 3, title: "Movie C", posterPath: "/posterC.jpg", releaseYear: 2021, rating: 7.0)
        ],
        currentPage: 2,
        hasMorePages: false,
        asOf: Date()
    )
}
