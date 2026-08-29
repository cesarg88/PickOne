import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("Movie history acceptance", .serialized)
struct MovieHistoryAcceptanceTests {
    @Test("a successful Detail change refreshes My movies and forwards Home change")
    func successfulDetailChangeRefreshesMyMovies() async throws {
        let initial = try historyState(preference: nil)
        let updated = try historyState(preference: .reaction(.loveIt))
        let history = MutableMyMoviesUseCase(states: [initial])
        let model = MyMoviesViewModel(getMyMovies: history)
        await model.load()
        await history.setStates([updated])
        var homeChanges: [DecisionViewerStateChange] = []
        let dependencies = detailDependencies(
            viewerStateDidChange: { homeChanges.append($0) }
        ).refreshingProjection {
            await model.load()
        }
        let change = try decisionChange(movieID: initial.movieID, impact: .tasteChanged)

        dependencies.viewerStateDidChange(change)
        let expectedState = MyMoviesViewState.loaded([
            MyMoviesItemPresentation(
                id: updated.movieID,
                title: updated.displayMetadata.title,
                releaseYear: nil,
                posterURL: nil,
                stateLabel: "Love it"
            ),
        ])
        await waitForMyMoviesState(model, expected: expectedState)

        #expect(model.state == expectedState)
        #expect(homeChanges == [change])
    }

    @Test("removing the final history state removes its My movies row")
    func finalStateRemovalRemovesHistoryRow() async throws {
        let initial = try historyState(preference: .notInterested, watched: false)
        let history = MutableMyMoviesUseCase(states: [initial])
        let model = MyMoviesViewModel(getMyMovies: history)
        await model.load()
        await history.setStates([])
        let dependencies = detailDependencies().refreshingProjection {
            await model.load()
        }

        try dependencies.viewerStateDidChange(
            decisionChange(movieID: initial.movieID, impact: .eligibilityChanged)
        )
        await waitForMyMoviesState(model, expected: .empty)

        #expect(model.state == .empty)
    }

    @Test("marking a saved movie watched removes it from Watchlist after returning")
    func markingSavedMovieWatchedRefreshesWatchlist() async throws {
        let watchlistRepository = MockWatchlistRepository()
        watchlistRepository.getAllItemsResult = [watchlistItem(movieID: 42)]
        let watchlistModel = WatchlistViewModel(
            getWatchlist: GetWatchlist(repository: watchlistRepository),
            setMembership: SetWatchlistMembership(repository: watchlistRepository)
        )
        await watchlistModel.load()
        let watched = try historyState(movieID: 42, preference: nil)
        let update = ViewerMovieStateChange(
            state: watched,
            impact: .eligibilityChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        var homeChanges: [DecisionViewerStateChange] = []
        let dependencies = try detailDependencies(
            feedbackState: savedState(movieID: 42),
            updates: RecordingFeedbackUpdate(outcomes: [.change(update)]),
            viewerStateDidChange: { homeChanges.append($0) }
        ).refreshingProjection {
            await watchlistModel.load()
        }
        let detailModel = dependencies.makeViewModel(movieID: 42)
        await detailModel.load()
        watchlistRepository.getAllItemsResult = []

        await detailModel.toggleWatched()
        await waitForWatchlistState(watchlistModel, expected: .empty)

        #expect(watchlistModel.state == .empty)
        #expect(homeChanges.count == 1)
    }

    @Test("a failed Detail edit changes neither My movies nor Watchlist")
    func failedDetailEditPreservesProjections() async throws {
        let historyState = try historyState(movieID: 7, preference: nil)
        let history = MutableMyMoviesUseCase(states: [historyState])
        let myMoviesModel = MyMoviesViewModel(getMyMovies: history)
        await myMoviesModel.load()

        let watchlistRepository = MockWatchlistRepository()
        watchlistRepository.getAllItemsResult = [watchlistItem(movieID: 42)]
        let watchlistModel = WatchlistViewModel(
            getWatchlist: GetWatchlist(repository: watchlistRepository),
            setMembership: SetWatchlistMembership(repository: watchlistRepository)
        )
        await watchlistModel.load()
        let initialMyMoviesState = myMoviesModel.state
        let initialWatchlistState = watchlistModel.state
        let initialHistoryLoads = await history.callCount
        let initialWatchlistLoads = watchlistRepository.loadAllItemsCallCount
        var homeChanges: [DecisionViewerStateChange] = []
        let dependencies = try detailDependencies(
            feedbackState: savedState(movieID: 42),
            updates: RecordingFeedbackUpdate(outcomes: [.failure]),
            viewerStateDidChange: { homeChanges.append($0) }
        ).refreshingProjection {
            await myMoviesModel.load()
            await watchlistModel.load()
        }
        let detailModel = dependencies.makeViewModel(movieID: 42)
        await detailModel.load()

        await detailModel.toggleWatched()

        #expect(detailModel.feedbackActionErrorMessage != nil)
        #expect(myMoviesModel.state == initialMyMoviesState)
        #expect(watchlistModel.state == initialWatchlistState)
        #expect(await history.callCount == initialHistoryLoads)
        #expect(watchlistRepository.loadAllItemsCallCount == initialWatchlistLoads)
        #expect(homeChanges.isEmpty)
    }

    private func detailDependencies(
        feedbackState: ViewerMovieState? = nil,
        updates: RecordingFeedbackUpdate = RecordingFeedbackUpdate(outcomes: []),
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void = { _ in }
    ) -> MovieDetailNavigationDependencies {
        MovieDetailNavigationDependencies(
            getMovieDetail: ImmediateFeedbackMovieDetailUseCase(),
            getViewerMovieState: SequencedFeedbackLoad(outcomes: [.state(feedbackState)]),
            updateViewerMovieState: updates,
            checkAvailability: FeedbackUnknownAvailability(),
            preparePlaybackOptions: FeedbackUnavailablePlaybackOptions(),
            viewerStateDidChange: viewerStateDidChange,
            eligibilityDidChange: { _ in }
        )
    }

    private func decisionChange(
        movieID: Int,
        impact: ViewerMovieStateChangeImpact
    ) throws -> DecisionViewerStateChange {
        try #require(DecisionViewerStateChange(
            movieID: movieID,
            impact: impact,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        ))
    }

    private func historyState(
        movieID: Int = 42,
        preference: MoviePreference?,
        watched: Bool = true
    ) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: MovieFeedbackMetadata(
                title: "Movie \(movieID)",
                releaseYear: nil,
                posterPath: nil
            ),
            watchState: watched ? .watched : .unwatched,
            preference: preference,
            watchlistIntent: nil,
            stateChangedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func savedState(movieID: Int) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: MovieFeedbackMetadata(
                title: "Saved movie",
                releaseYear: nil,
                posterPath: nil
            ),
            watchState: .unwatched,
            preference: nil,
            watchlistIntent: WatchlistIntent(addedAt: Date(timeIntervalSince1970: 100)),
            stateChangedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func watchlistItem(movieID: Int) -> WatchlistItem {
        WatchlistItem(
            id: movieID,
            addedAt: Date(timeIntervalSince1970: 100),
            movie: MovieSummary(
                id: movieID,
                title: "Saved movie",
                posterPath: nil,
                releaseYear: nil,
                rating: 0
            )
        )
    }

    private func waitForMyMoviesState(
        _ model: MyMoviesViewModel,
        expected: MyMoviesViewState
    ) async {
        for _ in 0 ..< 200 {
            if model.state == expected {
                return
            }
            await Task.yield()
        }
    }

    private func waitForWatchlistState(
        _ model: WatchlistViewModel,
        expected: WatchlistViewState
    ) async {
        for _ in 0 ..< 200 {
            if model.state == expected {
                return
            }
            await Task.yield()
        }
    }
}

private actor MutableMyMoviesUseCase: GetMyMoviesUseCase {
    private var states: [ViewerMovieState]
    private(set) var callCount = 0

    init(states: [ViewerMovieState]) {
        self.states = states
    }

    func execute() -> [ViewerMovieState] {
        callCount += 1
        return states
    }

    func setStates(_ states: [ViewerMovieState]) {
        self.states = states
    }
}
