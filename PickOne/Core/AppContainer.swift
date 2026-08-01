import Foundation

@MainActor
final class AppContainer {
    // MARK: - Infrastructure

    let imagePipeline: ImagePipeline

    // MARK: - Use Cases - Discovery

    let getDiscoveryFeed: GetDiscoveryFeedUseCase
    let getMovieDetail: GetMovieDetailUseCase
    let checkMovieAvailability: CheckMovieAvailabilityUseCase
    let preparePlaybackOptions: PreparePlaybackOptionsUseCase

    // MARK: - Use Cases - Watchlist

    let getWatchlist: GetWatchlistUseCase
    let setWatchlistMembership: SetWatchlistMembershipUseCase
    let setWatched: SetWatchedUseCase

    // MARK: - Use Cases - Search

    let searchMovies: SearchMoviesUseCase
    let searchHistory: SearchHistoryUseCase

    // MARK: - Use Cases - Recommendations

    let getChatRecommendations: GetChatRecommendationsUseCase

    // MARK: - ViewModels

    let discoveryViewModel: DiscoveryViewModel
    let watchlistViewModel: WatchlistViewModel
    let searchViewModel: SearchViewModel
    let recommendationViewModel: RecommendationViewModel

    init() {
        // MARK: - Network Layer

        let httpClient = URLSessionHTTPClient(
            baseURL: AppConfiguration.tmdbBaseURL,
            defaultTimeout: AppConfiguration.defaultRequestTimeout
        )

        let movieClient = TMDBMovieCatalogClient(
            httpClient: httpClient,
            apiKey: AppConfiguration.tmdbAPIKey
        )
        let availabilityClient = TMDBMovieAvailabilityClient(
            httpClient: httpClient,
            apiKey: AppConfiguration.tmdbAPIKey
        )

        // MARK: - Persistence Layer

        let localStore = UserDefaultsLocalStore()
        let cacheStore = MemoryCacheStore()
        let ttl = CacheTTL(
            discovery: AppConfiguration.discoveryFeedCacheTTL,
            detail: AppConfiguration.movieDetailCacheTTL,
            similar: AppConfiguration.movieDetailCacheTTL,
            credits: AppConfiguration.movieDetailCacheTTL
        )

        // MARK: - Repositories

        let movieRepository = DefaultMovieRepository(
            client: movieClient,
            cacheStore: cacheStore,
            ttl: ttl
        )
        let availabilityClock = SystemAvailabilityClock()
        let availabilityRepository = DefaultAvailabilityRepository(
            client: availabilityClient,
            clock: availabilityClock
        )

        let watchlistRepository = DefaultWatchlistRepository(
            localStore: localStore
        )

        let searchHistoryRepository = DefaultSearchHistoryRepository(
            localStore: localStore
        )

        let recommendationRepository = StubRecommendationRepository()

        // MARK: - Use Cases - Discovery

        getDiscoveryFeed = GetDiscoveryFeed(repository: movieRepository)
        getMovieDetail = GetMovieDetail(
            repository: movieRepository,
            watchlistRepository: watchlistRepository
        )
        let checkMovieAvailability = CheckMovieAvailability(
            repository: availabilityRepository,
            context: .spainPilot
        )
        self.checkMovieAvailability = checkMovieAvailability
        preparePlaybackOptions = PreparePlaybackOptions(
            checkAvailability: checkMovieAvailability,
            clock: availabilityClock
        )

        // MARK: - Use Cases - Watchlist

        getWatchlist = GetWatchlist(repository: watchlistRepository)
        setWatchlistMembership = SetWatchlistMembership(repository: watchlistRepository)
        setWatched = SetWatched(repository: watchlistRepository)

        // MARK: - Use Cases - Search

        searchMovies = SearchMovies(
            movieRepository: movieRepository,
            searchHistoryRepository: searchHistoryRepository
        )
        searchHistory = SearchHistory(repository: searchHistoryRepository)

        // MARK: - Use Cases - Recommendations

        getChatRecommendations = GetChatRecommendations(
            repository: recommendationRepository,
            movieRepository: movieRepository,
            minResults: AppConfiguration.minAIRecommendations,
            maxAllowedResults: AppConfiguration.maxAIRecommendations
        )

        // MARK: - Infrastructure

        imagePipeline = ImagePipeline()

        // MARK: - ViewModels

        discoveryViewModel = DiscoveryViewModel(
            getDiscoveryFeed: getDiscoveryFeed
        )

        watchlistViewModel = WatchlistViewModel(
            getWatchlist: getWatchlist,
            setMembership: setWatchlistMembership,
            setWatched: setWatched
        )

        searchViewModel = SearchViewModel(
            searchMovies: searchMovies,
            searchHistory: searchHistory
        )

        recommendationViewModel = RecommendationViewModel(
            getChatRecommendations: getChatRecommendations
        )
    }
}
