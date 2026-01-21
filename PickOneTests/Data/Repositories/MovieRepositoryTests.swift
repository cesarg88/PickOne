import Testing
import Foundation
@testable import PickOne

@Suite("MovieRepository Tests", .serialized)
struct MovieRepositoryTests {
    private func makeSUT(
        client: MockMovieCatalogClient = MockMovieCatalogClient(),
        cacheStore: TestCacheStore = TestCacheStore()
    ) -> (MovieRepository, MockMovieCatalogClient, TestCacheStore) {
        let ttl = CacheTTL(
            discovery: 60,
            detail: 60,
            similar: 60,
            credits: 60
        )
        let repo = MovieRepository(
            client: client,
            cacheStore: cacheStore,
            ttl: ttl
        )
        return (repo, client, cacheStore)
    }
    
    @Test("Return cache when not expired")
    func returnsCachedValueWhenFresh() async throws {
        let (sut, client, cache) = makeSUT()
        let key = CacheKey(rawValue: "discovery.topRated.page.1")
        let cachedPage = MoviePage(page: 1, totalPages: 2, movies: [TestFixtures.movieSummaryA])
        await cache.seed(value: cachedPage, for: key, expiresAt: Date().addingTimeInterval(60))
        
        let result = try await sut.getTopRated(page: 1, policy: .returnCacheElseLoad)
        
        #expect(result.value == cachedPage)
        #expect(result.isStale == false)
        #expect(await client.topRatedCallCount == 0)
    }
    
    @Test("Return stale cache and refresh in background")
    func returnsStaleCacheAndRefreshes() async throws {
        let (sut, client, cache) = makeSUT()
        let key = CacheKey(rawValue: "discovery.topRated.page.1")
        let cachedPage = MoviePage(page: 1, totalPages: 2, movies: [TestFixtures.movieSummaryA])
        await cache.seed(value: cachedPage, for: key, expiresAt: Date().addingTimeInterval(-10))
        
        let result = try await sut.getTopRated(page: 1, policy: .returnCacheElseLoad)
        
        #expect(result.value == cachedPage)
        #expect(result.isStale == true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        let refreshed = await cache.get(for: key, as: MoviePage.self)?.value
        
        #expect(refreshed == TestFixtures.topRatedPage)
        #expect(await client.topRatedCallCount == 1)
    }
    
    @Test("Refresh policy ignores cache")
    func refreshPolicyFetchesFromNetwork() async throws {
        let (sut, client, cache) = makeSUT()
        let key = CacheKey(rawValue: "discovery.topRated.page.1")
        let cachedPage = MoviePage(page: 1, totalPages: 2, movies: [TestFixtures.movieSummaryA])
        await cache.seed(value: cachedPage, for: key, expiresAt: Date().addingTimeInterval(60))
        
        let result = try await sut.getTopRated(page: 1, policy: .refresh)
        
        #expect(result.value == TestFixtures.topRatedPage)
        #expect(result.isStale == false)
        #expect(await client.topRatedCallCount == 1)
    }
    
    @Test("Deduplicates concurrent refresh requests")
    func deduplicatesInFlightRequests() async throws {
        let (sut, client, _) = makeSUT()
        await client.setDelay(nanoseconds: 150_000_000)
        
        async let first = sut.getTopRated(page: 1, policy: .refresh)
        async let second = sut.getTopRated(page: 1, policy: .refresh)
        
        let result1 = try await first
        let result2 = try await second
        
        #expect(result1.value == TestFixtures.topRatedPage)
        #expect(result2.value == TestFixtures.topRatedPage)
        #expect(await client.topRatedCallCount == 1)
    }
}

private final class TestCacheStore: CacheStore {
    private struct AnyCacheEntry {
        let value: Any
        let storedAt: Date
        let expiresAt: Date
    }
    
    private var entries: [String: AnyCacheEntry] = [:]
    
    func get<Value>(for key: CacheKey, as type: Value.Type) async -> CacheEntry<Value>? {
        guard let entry = entries[key.rawValue], let value = entry.value as? Value else {
            return nil
        }
        return CacheEntry(value: value, storedAt: entry.storedAt, expiresAt: entry.expiresAt)
    }
    
    func set<Value>(value: Value, for key: CacheKey, ttl: TimeInterval) async {
        let now = Date()
        let entry = AnyCacheEntry(value: value, storedAt: now, expiresAt: now.addingTimeInterval(ttl))
        entries[key.rawValue] = entry
    }
    
    func remove(for key: CacheKey) async {
        entries.removeValue(forKey: key.rawValue)
    }
    
    func seed<Value>(value: Value, for key: CacheKey, expiresAt: Date, storedAt: Date = Date()) async {
        let entry = AnyCacheEntry(value: value, storedAt: storedAt, expiresAt: expiresAt)
        entries[key.rawValue] = entry
    }
}

private actor MockMovieCatalogClient: MovieCatalogClientProtocol {
    private(set) var topRatedCallCount = 0
    private(set) var detailCallCount = 0
    private(set) var similarCallCount = 0
    private(set) var creditsCallCount = 0
    private var delay: UInt64 = 0
    
    func setDelay(nanoseconds: UInt64) async {
        delay = nanoseconds
    }
    
    func getTopRated(page: Int) async throws -> MovieListResponseDTO {
        topRatedCallCount += 1
        try await sleepIfNeeded()
        return TestFixtures.topRatedDTO
    }
    
    func getMovieDetail(id: Int) async throws -> MovieDetailDTO {
        detailCallCount += 1
        try await sleepIfNeeded()
        return TestFixtures.detailDTO
    }
    
    func getSimilarMovies(id: Int, page: Int) async throws -> MovieListResponseDTO {
        similarCallCount += 1
        try await sleepIfNeeded()
        return TestFixtures.topRatedDTO
    }
    
    func searchMovies(query: String, page: Int) async throws -> SearchResponseDTO {
        return SearchResponseDTO(page: 1, results: [], totalPages: 0, totalResults: 0)
    }
    
    func getMovieCredits(id: Int) async throws -> CreditsResponseDTO {
        creditsCallCount += 1
        try await sleepIfNeeded()
        return TestFixtures.creditsDTO
    }
    
    private func sleepIfNeeded() async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: delay)
        }
    }
}

private enum TestFixtures {
    static let movieSummaryA = MovieSummary(
        id: 1,
        title: "Movie A",
        posterPath: "/posterA.jpg",
        releaseYear: 2023,
        rating: 8.1
    )
    
    static let movieSummaryB = MovieSummary(
        id: 2,
        title: "Movie B",
        posterPath: "/posterB.jpg",
        releaseYear: 2022,
        rating: 7.4
    )
    
    static let topRatedPage = MoviePage(
        page: 1,
        totalPages: 2,
        movies: [movieSummaryA, movieSummaryB]
    )
    
    static let topRatedDTO = MovieListResponseDTO(
        page: 1,
        results: [
            MovieListItemDTO(
                adult: false,
                backdropPath: nil,
                genreIds: [18],
                id: 1,
                originalLanguage: "en",
                originalTitle: "Movie A",
                overview: "Overview A",
                popularity: 1.0,
                posterPath: "/posterA.jpg",
                releaseDate: "2023-06-01",
                title: "Movie A",
                video: false,
                voteAverage: 8.1,
                voteCount: 1200
            ),
            MovieListItemDTO(
                adult: false,
                backdropPath: nil,
                genreIds: [18],
                id: 2,
                originalLanguage: "en",
                originalTitle: "Movie B",
                overview: "Overview B",
                popularity: 1.0,
                posterPath: "/posterB.jpg",
                releaseDate: "2022-04-01",
                title: "Movie B",
                video: false,
                voteAverage: 7.4,
                voteCount: 800
            )
        ],
        totalPages: 2,
        totalResults: 20
    )
    
    static let detailDTO = MovieDetailDTO(
        adult: false,
        backdropPath: "/backdrop.jpg",
        budget: nil,
        genres: [GenreDTO(id: 18, name: "Drama")],
        homepage: nil,
        id: 1,
        imdbId: nil,
        originalLanguage: "en",
        originalTitle: "Movie A",
        overview: "Overview A",
        popularity: nil,
        posterPath: "/posterA.jpg",
        releaseDate: "2023-06-01",
        revenue: nil,
        runtime: 120,
        status: nil,
        tagline: nil,
        title: "Movie A",
        video: false,
        voteAverage: 8.1,
        voteCount: 1200
    )
    
    static let creditsDTO = CreditsResponseDTO(
        id: 1,
        cast: [
            CastMemberDTO(
                adult: nil,
                gender: nil,
                id: 10,
                knownForDepartment: nil,
                name: "Actor 1",
                originalName: nil,
                popularity: nil,
                profilePath: nil,
                castId: nil,
                character: "Hero",
                creditId: "credit-1",
                order: 0
            )
        ],
        crew: [
            CrewMemberDTO(
                adult: nil,
                gender: nil,
                id: 20,
                knownForDepartment: nil,
                name: "Director 1",
                originalName: nil,
                popularity: nil,
                profilePath: nil,
                creditId: "credit-2",
                department: "Directing",
                job: "Director"
            )
        ]
    )
}
