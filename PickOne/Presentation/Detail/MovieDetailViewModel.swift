import Foundation
import Observation

enum MovieDetailViewState: Equatable {
    case idle
    case loading
    case loaded(MovieDetailPresentationModel)
    case error(String)
}

@MainActor
@Observable
final class MovieDetailViewModel {
    let movieId: Int
    private let getMovieDetail: any GetMovieDetailUseCase
    private let getViewerMovieState: any GetViewerMovieStateUseCase
    private let updateViewerMovieState: any UpdateViewerMovieStateUseCase
    private let checkAvailability: any CheckMovieAvailabilityUseCase
    private let preparePlaybackOptionsUseCase: any PreparePlaybackOptionsUseCase
    private let viewerStateDidChange: @MainActor (DecisionViewerStateChange) -> Void
    private let eligibilityDidChange: @MainActor (DecisionEligibilityChange) -> Void
    @ObservationIgnored private var activeLoadID = UUID()
    @ObservationIgnored private var activeFeedbackLoadID = UUID()
    @ObservationIgnored private var activeMutationID = UUID()
    @ObservationIgnored private var availabilityOutcome: AvailabilityOutcome?
    @ObservationIgnored private var confirmedFeedbackState: ViewerMovieState?
    @ObservationIgnored private var feedbackMetadata: MovieFeedbackMetadata?
    @ObservationIgnored private var detailMetadata: MovieFeedbackMetadata?
    @ObservationIgnored private var hasConfirmedFeedback = false
    @ObservationIgnored private var isFeedbackSaving = false

    var state: MovieDetailViewState = .idle
    var availabilityState: MovieAvailabilityViewState = .loading
    var feedbackState: MovieFeedbackViewState = .loading
    var feedbackActionErrorMessage: String?

    init(
        movieId: Int,
        getMovieDetail: any GetMovieDetailUseCase,
        getViewerMovieState: any GetViewerMovieStateUseCase,
        updateViewerMovieState: any UpdateViewerMovieStateUseCase,
        checkAvailability: any CheckMovieAvailabilityUseCase,
        preparePlaybackOptions: any PreparePlaybackOptionsUseCase,
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void = { _ in },
        eligibilityDidChange: @escaping @MainActor (DecisionEligibilityChange) -> Void = { _ in }
    ) {
        self.movieId = movieId
        self.getMovieDetail = getMovieDetail
        self.getViewerMovieState = getViewerMovieState
        self.updateViewerMovieState = updateViewerMovieState
        self.checkAvailability = checkAvailability
        preparePlaybackOptionsUseCase = preparePlaybackOptions
        self.viewerStateDidChange = viewerStateDidChange
        self.eligibilityDidChange = eligibilityDidChange
    }

    // MARK: - Load

    func load() async {
        let loadID = UUID()
        activeLoadID = loadID
        state = .loading
        availabilityState = .loading
        availabilityOutcome = nil
        feedbackState = .loading

        async let detailLoad: Void = loadDetail(loadID: loadID)
        async let availabilityLoad: Void = loadAvailability(loadID: loadID)
        async let feedbackLoad: Void = loadFeedback()
        _ = await (detailLoad, availabilityLoad, feedbackLoad)
    }

    func retryFeedback() async {
        guard !isFeedbackSaving else { return }
        feedbackState = .loading
        await loadFeedback()
    }

    private func loadDetail(loadID: UUID) async {
        do {
            let cached = try await getMovieDetail.execute(
                id: movieId,
                policy: .returnCacheElseLoad
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return }
            publishDetail(cached.value)
            if cached.isStale {
                let refreshed = try await getMovieDetail.execute(
                    id: movieId,
                    policy: .refresh
                )
                try Task.checkCancellation()
                guard activeLoadID == loadID else { return }
                publishDetail(refreshed.value)
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeLoadID == loadID else { return }
            state = .error(error.localizedDescription)
        }
    }

    private func publishDetail(_ snapshot: MovieDetailSnapshot) {
        detailMetadata = try? MovieFeedbackMetadata(
            title: snapshot.movie.title,
            releaseYear: snapshot.movie.releaseYear,
            posterPath: snapshot.movie.posterPath
        )
        state = .loaded(MovieDetailPresentationMapper.map(snapshot: snapshot))
        if hasConfirmedFeedback {
            publishFeedbackState()
        }
    }

    private func loadAvailability(loadID: UUID) async {
        do {
            let outcome = try await checkAvailability.execute(
                movieID: movieId,
                policy: .useFreshCache
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return }
            availabilityOutcome = outcome
            availabilityState = AvailabilityPresentationMapper.map(
                outcome: outcome
            )
        } catch is CancellationError {
            return
        } catch {
            guard activeLoadID == loadID else { return }
            let outcome = AvailabilityOutcome.unknown(
                reason: .verificationFailed
            )
            availabilityOutcome = outcome
            availabilityState = .unknown
        }
    }

    private func loadFeedback() async {
        let loadID = UUID()
        activeFeedbackLoadID = loadID
        do {
            let loadedState = try await getViewerMovieState.execute(movieID: movieId)
            try Task.checkCancellation()
            guard activeFeedbackLoadID == loadID else { return }
            confirmedFeedbackState = loadedState
            feedbackMetadata = loadedState?.displayMetadata
            hasConfirmedFeedback = true
            publishFeedbackState()
        } catch is CancellationError {
            return
        } catch {
            guard activeFeedbackLoadID == loadID else { return }
            hasConfirmedFeedback = false
            feedbackState = .failure(
                "Your movie feedback couldn't be loaded. Please try again."
            )
        }
    }

    func preparePlaybackOptions() async -> URL? {
        guard let availabilityOutcome else {
            return nil
        }

        let loadID = activeLoadID
        do {
            let preparation = try await preparePlaybackOptionsUseCase.execute(
                movieID: movieId,
                currentOutcome: availabilityOutcome
            )
            try Task.checkCancellation()
            guard activeLoadID == loadID else { return nil }

            switch preparation {
                case let .open(url):
                    return url
                case let .updatedOutcome(outcome):
                    let didChange = outcome != availabilityOutcome
                    self.availabilityOutcome = outcome
                    availabilityState = AvailabilityPresentationMapper.map(
                        outcome: outcome
                    )
                    if didChange {
                        notifyEligibilityChange(cause: .availability)
                    }
                    return nil
                case .unavailable:
                    return nil
            }
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Feedback Actions

    func setReaction(_ reaction: MovieReaction) async {
        await apply(.assignReaction(reaction))
    }

    func removeReaction() async {
        await apply(.removeReaction)
    }

    func toggleWatched() async {
        let action: ViewerMovieStateTransition.Action =
            confirmedFeedbackState?.watchState.isWatched == true
                ? .markUnwatched
                : .markWatched
        await apply(action)
    }

    func toggleNotInterested() async {
        let action: ViewerMovieStateTransition.Action =
            confirmedFeedbackState?.isNotInterested == true
                ? .removeNotInterested
                : .setNotInterested
        await apply(action)
    }

    func toggleWatchlist() async {
        let action: ViewerMovieStateTransition.Action =
            confirmedFeedbackState?.watchlistIntent != nil
                ? .removeFromWatchlist
                : .saveToWatchlist
        await apply(action)
    }

    private func apply(_ action: ViewerMovieStateTransition.Action) async {
        guard !isFeedbackSaving,
              let metadata = mutationMetadata
        else {
            return
        }

        let mutationID = UUID()
        activeMutationID = mutationID
        activeFeedbackLoadID = UUID()
        isFeedbackSaving = true
        feedbackActionErrorMessage = nil
        publishFeedbackState()

        do {
            let change = try await updateViewerMovieState.execute(
                transition: ViewerMovieStateTransition(
                    movieID: movieId,
                    action: action
                ),
                metadata: metadata
            )
            guard activeMutationID == mutationID else { return }
            activeFeedbackLoadID = UUID()
            confirmedFeedbackState = change.state
            feedbackMetadata = change.state?.displayMetadata ?? metadata
            hasConfirmedFeedback = true
            isFeedbackSaving = false
            publishFeedbackState()
            notifyViewerStateChange(change)
        } catch is CancellationError {
            guard activeMutationID == mutationID else { return }
            activeFeedbackLoadID = UUID()
            isFeedbackSaving = false
            publishFeedbackState()
        } catch {
            guard activeMutationID == mutationID else { return }
            activeFeedbackLoadID = UUID()
            isFeedbackSaving = false
            publishFeedbackState()
            feedbackActionErrorMessage = error.localizedDescription
        }
    }

    private var mutationMetadata: MovieFeedbackMetadata? {
        detailMetadata ?? feedbackMetadata
    }

    private func publishFeedbackState() {
        feedbackState = .loaded(
            MovieFeedbackPresentationMapper.map(state: confirmedFeedbackState),
            isSaving: isFeedbackSaving,
            canSubmit: mutationMetadata != nil
        )
    }

    private func notifyViewerStateChange(_ change: ViewerMovieStateChange) {
        guard change.impact != .none,
              let decisionChange = DecisionViewerStateChange(
                  movieID: movieId,
                  impact: change.impact,
                  snapshotID: change.snapshotID
              )
        else {
            return
        }
        viewerStateDidChange(decisionChange)
    }

    private func notifyEligibilityChange(cause: DecisionEligibilityRepairCause) {
        guard let change = DecisionEligibilityChange(movieID: movieId, cause: cause) else {
            return
        }
        eligibilityDidChange(change)
    }
}
