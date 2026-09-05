import Observation

enum HomeQuickFeedbackState: Equatable {
    case idle
    case saving
    case submitted
    case failed
}

@MainActor
@Observable
final class HomeQuickFeedbackViewModel {
    private let movieID: Int
    private let metadata: MovieFeedbackMetadata
    private let updateViewerMovieState: any UpdateViewerMovieStateUseCase
    private let viewerStateDidChange: @MainActor (DecisionViewerStateChange) -> Void
    @ObservationIgnored private var failedAction: ViewerMovieStateTransition.Action?

    var state = HomeQuickFeedbackState.idle

    init(
        movieID: Int,
        metadata: MovieFeedbackMetadata,
        updateViewerMovieState: any UpdateViewerMovieStateUseCase,
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void
    ) {
        self.movieID = movieID
        self.metadata = metadata
        self.updateViewerMovieState = updateViewerMovieState
        self.viewerStateDidChange = viewerStateDidChange
    }

    func submit(_ action: ViewerMovieStateTransition.Action) async {
        guard state != .saving, state != .submitted else { return }
        state = .saving

        do {
            let change = try await updateViewerMovieState.execute(
                transition: ViewerMovieStateTransition(
                    movieID: movieID,
                    action: action
                ),
                metadata: metadata
            )
            guard let decisionChange = DecisionViewerStateChange(
                movieID: movieID,
                impact: change.impact,
                snapshotID: change.snapshotID
            ) else {
                state = .idle
                return
            }
            failedAction = nil
            state = .submitted
            viewerStateDidChange(decisionChange)
        } catch is CancellationError {
            state = .idle
        } catch {
            failedAction = action
            state = .failed
        }
    }

    func retry() async {
        guard let failedAction else { return }
        await submit(failedAction)
    }

    func cancelFailure() {
        guard state == .failed else { return }
        failedAction = nil
        state = .idle
    }
}
