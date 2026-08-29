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
    let getMyMovies: GetMyMoviesUseCase
    let getViewerMovieState: GetViewerMovieStateUseCase
    let updateViewerMovieState: UpdateViewerMovieStateUseCase

    // MARK: - Use Cases - Search

    let searchMovies: SearchMoviesUseCase
    let searchHistory: SearchHistoryUseCase

    // MARK: - Use Cases - Recommendations

    let getChatRecommendations: GetChatRecommendationsUseCase
    let threeForTonight: any ThreeForTonightUseCase

    // MARK: - Use Cases - Viewer Profile

    let manageViewerProfile: ManageViewerProfileUseCase
    let getViewerStateRecoveryNotice: GetViewerStateRecoveryNoticeUseCase
    let resetUnrecoverableViewerState: ResetUnrecoverableViewerStateUseCase
    let resolveCalibrationCatalog: ResolveCalibrationCatalogUseCase

    // MARK: - ViewModels

    let discoveryViewModel: DiscoveryViewModel
    let watchlistViewModel: WatchlistViewModel
    let searchViewModel: SearchViewModel
    let recommendationViewModel: RecommendationViewModel
    let homeDecisionViewModel: HomeDecisionViewModel
    let viewerProfileViewModel: ViewerProfileViewModel
    let myMoviesViewModel: MyMoviesViewModel

    init() {
        let repositories = Self.makeRepositories()
        let useCases = Self.makeUseCases(repositories: repositories)
        let movieDetailUseCase: any GetMovieDetailUseCase
        let availabilityUseCase: any CheckMovieAvailabilityUseCase
        let playbackOptionsUseCase: any PreparePlaybackOptionsUseCase
        let homeUseCase: any ThreeForTonightUseCase

        if AppConfiguration.isUITesting {
            movieDetailUseCase = UITestingMovieDetailUseCase()
            availabilityUseCase = UITestingAvailabilityUseCase()
            playbackOptionsUseCase = UITestingPreparePlaybackOptionsUseCase()
            homeUseCase = UITestingThreeForTonightUseCase()
        } else {
            movieDetailUseCase = useCases.getMovieDetail
            availabilityUseCase = useCases.checkMovieAvailability
            playbackOptionsUseCase = useCases.preparePlaybackOptions
            homeUseCase = useCases.threeForTonight
        }

        getDiscoveryFeed = useCases.getDiscoveryFeed
        getMovieDetail = movieDetailUseCase
        checkMovieAvailability = availabilityUseCase
        preparePlaybackOptions = playbackOptionsUseCase
        getWatchlist = useCases.getWatchlist
        setWatchlistMembership = useCases.setWatchlistMembership
        getMyMovies = useCases.getMyMovies
        getViewerMovieState = useCases.getViewerMovieState
        updateViewerMovieState = useCases.updateViewerMovieState
        searchMovies = useCases.searchMovies
        searchHistory = useCases.searchHistory
        getChatRecommendations = useCases.getChatRecommendations
        threeForTonight = homeUseCase
        manageViewerProfile = useCases.manageViewerProfile
        getViewerStateRecoveryNotice = useCases.getViewerStateRecoveryNotice
        resetUnrecoverableViewerState = useCases.resetUnrecoverableViewerState
        resolveCalibrationCatalog = useCases.resolveCalibrationCatalog
        imagePipeline = ImagePipeline()
        discoveryViewModel = DiscoveryViewModel(
            getDiscoveryFeed: useCases.getDiscoveryFeed
        )
        let homeDecisionViewModel = HomeDecisionViewModel(
            threeForTonight: homeUseCase
        )
        self.homeDecisionViewModel = homeDecisionViewModel
        watchlistViewModel = WatchlistViewModel(
            getWatchlist: useCases.getWatchlist,
            setMembership: useCases.setWatchlistMembership,
            eligibilityDidChange: { [weak homeDecisionViewModel] change in
                homeDecisionViewModel?.repair(after: change)
            }
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
            getRecoveryNotice: useCases.getViewerStateRecoveryNotice,
            resetUnrecoverableViewerState: useCases.resetUnrecoverableViewerState,
            resetsProfileForUITests: AppConfiguration.resetsViewerProfileForUITests
        )
        myMoviesViewModel = MyMoviesViewModel(getMyMovies: useCases.getMyMovies)
    }
}

private extension AppContainer {
    struct Repositories {
        let movie: DefaultMovieRepository
        let calibrationMovieMetadata: DefaultCalibrationMetadataRepository
        let availability: DefaultAvailabilityRepository
        let viewerState: LocalViewerStateRepository
        let viewerProfile: LocalViewerProfileRepositoryAdapter
        let watchlist: LocalViewerStateWatchlistAdapter
        let searchHistory: DefaultSearchHistoryRepository
        let recommendation: StubRecommendationRepository
        let decisionCandidate: DefaultDecisionCandidateRepository
        let decisionSet: DefaultDecisionSetRepository
        let calibrationCatalog: DefaultCalibrationCatalogRepository
        let availabilityClock: SystemAvailabilityClock
    }

    struct UseCases {
        let getDiscoveryFeed: GetDiscoveryFeed
        let getMovieDetail: GetMovieDetail
        let checkMovieAvailability: CheckMovieAvailability
        let preparePlaybackOptions: PreparePlaybackOptions
        let getWatchlist: GetWatchlist
        let setWatchlistMembership: SetWatchlistMembership
        let getMyMovies: GetMyMovies
        let getViewerMovieState: GetViewerMovieState
        let updateViewerMovieState: UpdateViewerMovieState
        let searchMovies: SearchMovies
        let searchHistory: SearchHistory
        let getChatRecommendations: GetChatRecommendations
        let threeForTonight: ThreeForTonightCoordinator
        let manageViewerProfile: ManageViewerProfile
        let getCalibrationMovieMetadata: GetCalibrationMovieMetadata
        let getViewerStateRecoveryNotice: GetViewerStateRecoveryNotice
        let resetUnrecoverableViewerState: ResetUnrecoverableViewerState
        let resolveCalibrationCatalog: ResolveCalibrationCatalog
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
        let viewerStateFileStore: any LocalViewerStateFileStore =
            (try? ApplicationSupportViewerStateStore()) ??
            UnavailableLocalViewerStateFileStore()
        let legacyViewerState = UserDefaultsLegacyViewerStateSource()
        let viewerState = LocalViewerStateRepository(
            fileStore: viewerStateFileStore,
            legacySource: legacyViewerState,
            legacyResetter: legacyViewerState
        )
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
            viewerState: viewerState,
            viewerProfile: LocalViewerProfileRepositoryAdapter(
                repository: viewerState
            ),
            watchlist: LocalViewerStateWatchlistAdapter(
                repository: viewerState
            ),
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
            calibrationCatalog: makeCalibrationCatalogRepository(),
            availabilityClock: availabilityClock
        )
    }

    static func makeCalibrationCatalogRepository() -> DefaultCalibrationCatalogRepository {
        let remote: any CalibrationCatalogRemoteSource = if let endpoint = AppConfiguration
            .calibrationCatalogURL,
            let client = try? HTTPSCalibrationCatalogClient(endpoint: endpoint)
        {
            DefaultCalibrationCatalogRemoteSource(client: client)
        } else {
            UnavailableCatalogRemoteSource()
        }
        let cache: any CalibrationCatalogCacheStore =
            (try? CachesCalibrationCatalogStore()) ??
            UnavailableCalibrationCatalogCacheStore()
        let bundled: any BundledCalibrationCatalogSource = if let source =
            try? FileBundledCalibrationCatalogSource(
                resourceURL: Bundle.main.url(
                    forResource: "calibration-catalog-es-ES-v1",
                    withExtension: "json"
                )
            )
        {
            source
        } else {
            UnavailableBundledCatalogSource()
        }
        return DefaultCalibrationCatalogRepository(
            remote: remote,
            cache: cache,
            bundled: bundled
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
            candidateRepository: repositories.decisionCandidate,
            movieRepository: repositories.movie,
            availabilityRepository: repositories.availability
        )
        return UseCases(
            getDiscoveryFeed: GetDiscoveryFeed(repository: repositories.movie),
            getMovieDetail: GetMovieDetail(repository: repositories.movie),
            checkMovieAvailability: checkAvailability,
            preparePlaybackOptions: PreparePlaybackOptions(
                checkAvailability: checkAvailability,
                clock: repositories.availabilityClock
            ),
            getWatchlist: GetWatchlist(repository: repositories.watchlist),
            setWatchlistMembership: SetWatchlistMembership(repository: repositories.watchlist),
            getMyMovies: GetMyMovies(repository: repositories.viewerState),
            getViewerMovieState: GetViewerMovieState(
                repository: repositories.viewerState
            ),
            updateViewerMovieState: UpdateViewerMovieState(
                repository: repositories.viewerState
            ),
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
                viewerMovieStateRepository: repositories.viewerState,
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
            ),
            getViewerStateRecoveryNotice: GetViewerStateRecoveryNotice(
                repository: ViewerStateRecoveryNoticeAdapter(
                    repository: repositories.viewerState
                )
            ),
            resetUnrecoverableViewerState: ResetUnrecoverableViewerState(
                repository: ViewerStateDestructiveRecoveryAdapter(
                    repository: repositories.viewerState
                )
            ),
            resolveCalibrationCatalog: ResolveCalibrationCatalog(
                repository: repositories.calibrationCatalog
            )
        )
    }
}
