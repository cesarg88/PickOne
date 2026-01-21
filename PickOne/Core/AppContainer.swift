import Foundation

@MainActor
final class AppContainer {
    let imagePipeline: ImagePipeline
    let getDiscoveryFeed: GetDiscoveryFeedUseCase
    let getMovieDetail: GetMovieDetailUseCase
    let discoveryModel: DiscoveryModel
    
    init() {
        let httpClient = URLSessionHTTPClient(
            baseURL: AppConfiguration.tmdbBaseURL,
            defaultTimeout: AppConfiguration.defaultRequestTimeout
        )
        
        let movieClient = MovieCatalogClient(
            httpClient: httpClient,
            apiKey: AppConfiguration.tmdbAPIKey
        )
        
        let cacheStore = MemoryCacheStore()
        let ttl = CacheTTL(
            discovery: AppConfiguration.discoveryFeedCacheTTL,
            detail: AppConfiguration.movieDetailCacheTTL,
            similar: AppConfiguration.movieDetailCacheTTL,
            credits: AppConfiguration.movieDetailCacheTTL
        )
        
        let movieRepository = DefaultMovieRepository(
            client: movieClient,
            cacheStore: cacheStore,
            ttl: ttl
        )
        
        self.getDiscoveryFeed = GetDiscoveryFeed(repository: movieRepository)
        self.getMovieDetail = GetMovieDetail(repository: movieRepository)
        self.imagePipeline = ImagePipeline()
        self.discoveryModel = DiscoveryModel(getDiscoveryFeed: self.getDiscoveryFeed)
    }
}
