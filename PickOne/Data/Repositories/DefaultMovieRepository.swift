import Foundation

final class DefaultMovieRepository {
    private let client: MovieCatalogClient
    private let cacheStore: CacheStore
    private let ttl: CacheTTL
    private let inFlight = InFlightStore()
    
    init(client: MovieCatalogClient, cacheStore: CacheStore, ttl: CacheTTL) {
        self.client = client
        self.cacheStore = cacheStore
        self.ttl = ttl
    }
}

extension DefaultMovieRepository: MovieRepository {
    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        let key = CacheKey(rawValue: "discovery.topRated.page.\(page)")
        if policy == .returnCacheElseLoad,
           let cached: CacheEntry<MoviePage> = await cacheStore.get(for: key, as: MoviePage.self) {
            if cached.isExpired {
                Task { [weak self] in
                    _ = try? await self?.fetchTopRatedDedup(page: page, cacheKey: key)
                }
            }
            return CacheResult(value: cached.value, isStale: cached.isExpired)
        }
        let fresh = try await fetchTopRatedDedup(page: page, cacheKey: key)
        return CacheResult(value: fresh, isStale: false)
    }
    
    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie> {
        let key = CacheKey(rawValue: "movie.detail.\(id)")
        if policy == .returnCacheElseLoad,
           let cached: CacheEntry<Movie> = await cacheStore.get(for: key, as: Movie.self) {
            if cached.isExpired {
                Task { [weak self] in
                    _ = try? await self?.fetchMovieDetailDedup(id: id, cacheKey: key)
                }
            }
            return CacheResult(value: cached.value, isStale: cached.isExpired)
        }
        let fresh = try await fetchMovieDetailDedup(id: id, cacheKey: key)
        return CacheResult(value: fresh, isStale: false)
    }
    
    func getSimilarMovies(id: Int, page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        let key = CacheKey(rawValue: "movie.similar.\(id).page.\(page)")
        if policy == .returnCacheElseLoad,
           let cached: CacheEntry<MoviePage> = await cacheStore.get(for: key, as: MoviePage.self) {
            if cached.isExpired {
                Task { [weak self] in
                    _ = try? await self?.fetchSimilarMoviesDedup(id: id, page: page, cacheKey: key)
                }
            }
            return CacheResult(value: cached.value, isStale: cached.isExpired)
        }
        let fresh = try await fetchSimilarMoviesDedup(id: id, page: page, cacheKey: key)
        return CacheResult(value: fresh, isStale: false)
    }
    
    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits> {
        let key = CacheKey(rawValue: "movie.credits.\(id)")
        if policy == .returnCacheElseLoad,
           let cached: CacheEntry<Credits> = await cacheStore.get(for: key, as: Credits.self) {
            if cached.isExpired {
                Task { [weak self] in
                    _ = try? await self?.fetchCreditsDedup(id: id, cacheKey: key)
                }
            }
            return CacheResult(value: cached.value, isStale: cached.isExpired)
        }
        let fresh = try await fetchCreditsDedup(id: id, cacheKey: key)
        return CacheResult(value: fresh, isStale: false)
    }
    
    func searchMovies(query: String, page: Int) async throws -> MoviePage {
        let response = try await client.searchMovies(query: query, page: page)
        return MoviePage(
            page: response.page,
            totalPages: response.totalPages,
            movies: response.results.map(MovieMapper.mapSummary)
        )
    }
}
private extension DefaultMovieRepository {
    func fetchTopRated(page: Int, cacheKey: CacheKey) async throws -> MoviePage {
        let response = try await client.getTopRated(page: page)
        let pageValue = MoviePage(
            page: response.page,
            totalPages: response.totalPages,
            movies: response.results.map(MovieMapper.mapSummary)
        )
        await cacheStore.set(value: pageValue, for: cacheKey, ttl: ttl.discovery)
        return pageValue
    }
    
    func fetchTopRatedDedup(page: Int, cacheKey: CacheKey) async throws -> MoviePage {
        try await inFlight.run(key: cacheKey.rawValue) { [self] in
            try await self.fetchTopRated(page: page, cacheKey: cacheKey)
        }
    }
    
    func fetchMovieDetail(id: Int, cacheKey: CacheKey) async throws -> Movie {
        let response = try await client.getMovieDetail(id: id)
        let movie = MovieMapper.mapDetail(from: response)
        await cacheStore.set(value: movie, for: cacheKey, ttl: ttl.detail)
        return movie
    }
    
    func fetchMovieDetailDedup(id: Int, cacheKey: CacheKey) async throws -> Movie {
        try await inFlight.run(key: cacheKey.rawValue) { [self] in
            try await self.fetchMovieDetail(id: id, cacheKey: cacheKey)
        }
    }
    
    func fetchSimilarMovies(id: Int, page: Int, cacheKey: CacheKey) async throws -> MoviePage {
        let response = try await client.getSimilarMovies(id: id, page: page)
        let pageValue = MoviePage(
            page: response.page,
            totalPages: response.totalPages,
            movies: response.results.map(MovieMapper.mapSummary)
        )
        await cacheStore.set(value: pageValue, for: cacheKey, ttl: ttl.similar)
        return pageValue
    }
    
    func fetchSimilarMoviesDedup(id: Int, page: Int, cacheKey: CacheKey) async throws -> MoviePage {
        try await inFlight.run(key: cacheKey.rawValue) { [self] in
            try await self.fetchSimilarMovies(id: id, page: page, cacheKey: cacheKey)
        }
    }
    
    func fetchCredits(id: Int, cacheKey: CacheKey) async throws -> Credits {
        let response = try await client.getMovieCredits(id: id)
        let credits = MovieMapper.mapCredits(from: response)
        await cacheStore.set(value: credits, for: cacheKey, ttl: ttl.credits)
        return credits
    }
    
    func fetchCreditsDedup(id: Int, cacheKey: CacheKey) async throws -> Credits {
        try await inFlight.run(key: cacheKey.rawValue) { [self] in
            try await self.fetchCredits(id: id, cacheKey: cacheKey)
        }
    }
}

struct CacheTTL: Sendable {
    let discovery: TimeInterval
    let detail: TimeInterval
    let similar: TimeInterval
    let credits: TimeInterval
}

private actor InFlightStore {
    private var tasks: [String: Any] = [:]
    
    func run<Value: Sendable>(
        key: String,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        if let existing = tasks[key] as? Task<Value, Error> {
            return try await existing.value
        }
        
        let task = Task { try await operation() }
        tasks[key] = task
        defer { tasks[key] = nil }
        return try await task.value
    }
}
