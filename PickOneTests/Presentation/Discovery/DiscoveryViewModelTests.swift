import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("DiscoveryViewModel Tests", .serialized)
struct DiscoveryViewModelTests {
    @Test("loadInitial maps and sets loaded state")
    func loadInitialMapsAndSetsLoadedState() async {
        let useCase = MockGetDiscoveryFeedUseCase(results: [
            .success(CacheResult(value: TestFixtures.snapshotPage1, isStale: false)),
        ])

        let sut = DiscoveryViewModel(getDiscoveryFeed: useCase)
        await sut.loadInitial()

        guard case let .loaded(data) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(data.currentPage == 1)
        #expect(data.hasMorePages == true)
        #expect(data.movies.count == 2)
        #expect(data.movies[0].title == "Movie A")
    }

    @Test("loadInitial error sets error state")
    func loadInitialErrorSetsErrorState() async {
        let useCase = MockGetDiscoveryFeedUseCase(results: [
            .failure(TestError.fetchFailed),
        ])

        let sut = DiscoveryViewModel(getDiscoveryFeed: useCase)
        await sut.loadInitial()

        guard case .error = sut.state else {
            Issue.record("Expected error state")
            return
        }
    }

    @Test("loadNextPageIfNeeded appends results")
    func loadNextPageAppendsResults() async throws {
        let useCase = MockGetDiscoveryFeedUseCase(results: [
            .success(CacheResult(value: TestFixtures.snapshotPage1, isStale: false)),
            .success(CacheResult(value: TestFixtures.snapshotPage2, isStale: false)),
        ])

        let sut = DiscoveryViewModel(getDiscoveryFeed: useCase)
        await sut.loadInitial()

        guard case let .loaded(initial) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }

        let lastMovie = try #require(initial.movies.last)
        await sut.loadNextPageIfNeeded(current: lastMovie)

        guard case let .loaded(appended) = sut.state else {
            Issue.record("Expected loaded state after append")
            return
        }

        #expect(appended.currentPage == 2)
        #expect(appended.movies.count == 3)
        #expect(appended.movies.last?.title == "Movie C")
    }
}

private actor MockGetDiscoveryFeedUseCase: GetDiscoveryFeedUseCase {
    private let results: [Result<CacheResult<DiscoverySnapshot>, Error>]
    private var callIndex = 0

    init(results: [Result<CacheResult<DiscoverySnapshot>, Error>]) {
        self.results = results
    }

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
            MovieSummary(id: 2, title: "Movie B", posterPath: "/posterB.jpg", releaseYear: 2022, rating: 7.4),
        ],
        currentPage: 1,
        hasMorePages: true,
        asOf: Date()
    )

    static let snapshotPage2 = DiscoverySnapshot(
        movies: [
            MovieSummary(id: 3, title: "Movie C", posterPath: "/posterC.jpg", releaseYear: 2021, rating: 7.0),
        ],
        currentPage: 2,
        hasMorePages: false,
        asOf: Date()
    )
}
