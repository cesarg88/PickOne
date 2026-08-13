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
    let threeForTonight: any ThreeForTonightUseCase

    // MARK: - Use Cases - Viewer Profile

    let manageViewerProfile: ManageViewerProfileUseCase

    // MARK: - ViewModels

    let discoveryViewModel: DiscoveryViewModel
    let watchlistViewModel: WatchlistViewModel
    let searchViewModel: SearchViewModel
    let recommendationViewModel: RecommendationViewModel
    let viewerProfileViewModel: ViewerProfileViewModel

    init() {
        let repositories = Self.makeRepositories()
        let useCases = Self.makeUseCases(repositories: repositories)

        getDiscoveryFeed = useCases.getDiscoveryFeed
        getMovieDetail = useCases.getMovieDetail
        checkMovieAvailability = useCases.checkMovieAvailability
        preparePlaybackOptions = useCases.preparePlaybackOptions
        getWatchlist = useCases.getWatchlist
        setWatchlistMembership = useCases.setWatchlistMembership
        setWatched = useCases.setWatched
        searchMovies = useCases.searchMovies
        searchHistory = useCases.searchHistory
        getChatRecommendations = useCases.getChatRecommendations
        threeForTonight = useCases.threeForTonight
        manageViewerProfile = useCases.manageViewerProfile
        imagePipeline = ImagePipeline()
        discoveryViewModel = DiscoveryViewModel(
            getDiscoveryFeed: useCases.getDiscoveryFeed
        )
        watchlistViewModel = WatchlistViewModel(
            getWatchlist: useCases.getWatchlist,
            setMembership: useCases.setWatchlistMembership,
            setWatched: useCases.setWatched
        )
        searchViewModel = SearchViewModel(
            searchMovies: useCases.searchMovies,
            searchHistory: useCases.searchHistory
        )
        recommendationViewModel = RecommendationViewModel(
            getChatRecommendations: useCases.getChatRecommendations
        )
        viewerProfileViewModel = ViewerProfileViewModel(
            manageProfile: useCases.manageViewerProfile,
            getMovieMetadata: useCases.getCalibrationMovieMetadata,
            resetsProfileForUITests: AppConfiguration.resetsViewerProfileForUITests
        )
    }
}

private extension AppContainer {
    struct Repositories {
        let movie: DefaultMovieRepository
        let calibrationMovieMetadata: DefaultCalibrationMetadataRepository
        let availability: DefaultAvailabilityRepository
        let viewerProfile: DefaultViewerProfileRepository
        let watchlist: DefaultWatchlistRepository
        let searchHistory: DefaultSearchHistoryRepository
        let recommendation: StubRecommendationRepository
        let decisionCandidate: DefaultDecisionCandidateRepository
        let decisionSet: DefaultDecisionSetRepository
        let availabilityClock: SystemAvailabilityClock
    }

    struct UseCases {
        let getDiscoveryFeed: GetDiscoveryFeed
        let getMovieDetail: GetMovieDetail
        let checkMovieAvailability: CheckMovieAvailability
        let preparePlaybackOptions: PreparePlaybackOptions
        let getWatchlist: GetWatchlist
        let setWatchlistMembership: SetWatchlistMembership
        let setWatched: SetWatched
        let searchMovies: SearchMovies
        let searchHistory: SearchHistory
        let getChatRecommendations: GetChatRecommendations
        let threeForTonight: ThreeForTonightCoordinator
        let manageViewerProfile: ManageViewerProfile
        let getCalibrationMovieMetadata: GetCalibrationMovieMetadata
    }

    static func makeRepositories() -> Repositories {
        let httpClient = URLSessionHTTPClient(
            baseURL: AppConfiguration.tmdbBaseURL,
            defaultTimeout: AppConfiguration.defaultRequestTimeout
        )
        let movieClient = TMDBMovieCatalogClient(
            httpClient: httpClient,
            apiKey: AppConfiguration.tmdbAPIKey
        )
        let availabilityClock = SystemAvailabilityClock()
        let localStore = UserDefaultsLocalStore()
        return Repositories(
            movie: DefaultMovieRepository(
                client: movieClient,
                cacheStore: MemoryCacheStore(),
                ttl: CacheTTL(
                    discovery: AppConfiguration.discoveryFeedCacheTTL,
                    detail: AppConfiguration.movieDetailCacheTTL,
                    similar: AppConfiguration.movieDetailCacheTTL,
                    credits: AppConfiguration.movieDetailCacheTTL
                )
            ),
            calibrationMovieMetadata: DefaultCalibrationMetadataRepository(
                client: TMDBCalibrationMovieMetadataClient(
                    httpClient: httpClient,
                    apiKey: AppConfiguration.tmdbAPIKey
                )
            ),
            availability: DefaultAvailabilityRepository(
                client: TMDBMovieAvailabilityClient(
                    httpClient: httpClient,
                    apiKey: AppConfiguration.tmdbAPIKey
                ),
                clock: availabilityClock
            ),
            viewerProfile: DefaultViewerProfileRepository(
                store: UserDefaultsViewerProfileDataStore()
            ),
            watchlist: DefaultWatchlistRepository(localStore: localStore),
            searchHistory: DefaultSearchHistoryRepository(localStore: localStore),
            recommendation: StubRecommendationRepository(),
            decisionCandidate: DefaultDecisionCandidateRepository(
                client: TMDBDecisionCandidateClient(
                    httpClient: httpClient,
                    apiKey: AppConfiguration.tmdbAPIKey
                )
            ),
            decisionSet: DefaultDecisionSetRepository(
                store: UserDefaultsDecisionSetDataStore()
            ),
            availabilityClock: availabilityClock
        )
    }

    static func makeUseCases(repositories: Repositories) -> UseCases {
        let checkAvailability = CheckMovieAvailability(
            repository: repositories.availability,
            getCurrentViewingContext: GetCurrentViewingContext(
                repository: repositories.viewerProfile
            )
        )
        let inputAssembler = AssembleDecisionEngineInput(
            viewerProfileRepository: repositories.viewerProfile,
            watchlistRepository: repositories.watchlist,
            candidateRepository: repositories.decisionCandidate,
            movieRepository: repositories.movie,
            availabilityRepository: repositories.availability
        )
        return UseCases(
            getDiscoveryFeed: GetDiscoveryFeed(repository: repositories.movie),
            getMovieDetail: GetMovieDetail(
                repository: repositories.movie,
                watchlistRepository: repositories.watchlist
            ),
            checkMovieAvailability: checkAvailability,
            preparePlaybackOptions: PreparePlaybackOptions(
                checkAvailability: checkAvailability,
                clock: repositories.availabilityClock
            ),
            getWatchlist: GetWatchlist(repository: repositories.watchlist),
            setWatchlistMembership: SetWatchlistMembership(repository: repositories.watchlist),
            setWatched: SetWatched(repository: repositories.watchlist),
            searchMovies: SearchMovies(
                movieRepository: repositories.movie,
                searchHistoryRepository: repositories.searchHistory
            ),
            searchHistory: SearchHistory(repository: repositories.searchHistory),
            getChatRecommendations: GetChatRecommendations(
                repository: repositories.recommendation,
                movieRepository: repositories.movie,
                minResults: AppConfiguration.minAIRecommendations,
                maxAllowedResults: AppConfiguration.maxAIRecommendations
            ),
            threeForTonight: ThreeForTonightCoordinator(
                viewerProfileRepository: repositories.viewerProfile,
                watchlistRepository: repositories.watchlist,
                decisionSetRepository: repositories.decisionSet,
                inputAssembler: inputAssembler,
                movieRepository: repositories.movie,
                availabilityRepository: repositories.availability,
                signer: StableDecisionCycleSigner()
            ),
            manageViewerProfile: ManageViewerProfile(
                repository: repositories.viewerProfile,
                catalog: .spainHouseholdV1
            ),
            getCalibrationMovieMetadata: GetCalibrationMovieMetadata(
                repository: repositories.calibrationMovieMetadata
            )
        )
    }
}
