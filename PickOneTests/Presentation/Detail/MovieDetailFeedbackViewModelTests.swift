import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("Movie Detail feedback", .serialized)
struct MovieDetailFeedbackViewModelTests {
    @Test("feedback load failure does not block usable movie content")
    func feedbackFailureIsIndependent() async {
        let sut = makeSUT(feedbackLoads: [.failure])

        await sut.load()

        guard case .loaded = sut.state else {
            Issue.record("Expected movie content to remain loaded")
            return
        }
        guard case .failure = sut.feedbackState else {
            Issue.record("Expected an independent feedback failure")
            return
        }
    }

    @Test("feedback load retry can recover independently")
    func feedbackRetryRecovers() async throws {
        let current = try state(
            watchState: .watched,
            preference: .reaction(.itWasOkay)
        )
        let sut = makeSUT(feedbackLoads: [
            .failure,
            .state(current),
        ])
        await sut.load()

        await sut.retryFeedback()

        assertFeedback(
            sut.feedbackState,
            reaction: .itWasOkay,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
    }

    @Test("movie content failure does not discard offline feedback state")
    func detailFailurePreservesOfflineFeedback() async throws {
        let offline = try state(
            watchState: .watched,
            preference: .reaction(.likeIt)
        )
        let sut = makeSUT(
            detail: FailingMovieDetailUseCase(),
            feedbackLoads: [.state(offline)]
        )

        await sut.load()

        guard case .error = sut.state else {
            Issue.record("Expected movie content failure")
            return
        }
        assertFeedback(
            sut.feedbackState,
            reaction: .likeIt,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
    }

    @Test("successful reaction publishes confirmed state and one typed Home change")
    func reactionSuccessPublishesOneHomeChange() async throws {
        let confirmed = try state(
            watchState: .watched,
            preference: .reaction(.loveIt)
        )
        let change = ViewerMovieStateChange(
            state: confirmed,
            impact: .tasteChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let updates = RecordingFeedbackUpdate(outcomes: [.change(change)])
        var homeChanges: [DecisionViewerStateChange] = []
        let sut = makeSUT(
            feedbackLoads: [.state(nil)],
            updates: updates,
            viewerStateDidChange: { homeChanges.append($0) }
        )
        await sut.load()

        await sut.setReaction(.loveIt)

        assertFeedback(
            sut.feedbackState,
            reaction: .loveIt,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
        #expect(await updates.transitions == [ViewerMovieStateTransition(
            movieID: 42,
            action: .assignReaction(.loveIt)
        )])
        #expect(try await updates.metadata == [detailMetadata()])
        #expect(try homeChanges == [#require(DecisionViewerStateChange(
            movieID: 42,
            impact: .tasteChanged,
            snapshotID: change.snapshotID
        ))])
    }

    @Test("semantic no-op publishes confirmed state without notifying Home")
    func semanticNoOpDoesNotNotifyHome() async throws {
        let current = try state(
            watchState: .watched,
            preference: .reaction(.loveIt)
        )
        let noOp = ViewerMovieStateChange(
            state: current,
            impact: .none,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        var homeChanges: [DecisionViewerStateChange] = []
        let sut = makeSUT(
            feedbackLoads: [.state(current)],
            updates: RecordingFeedbackUpdate(outcomes: [.change(noOp)]),
            viewerStateDidChange: { homeChanges.append($0) }
        )
        await sut.load()

        await sut.setReaction(.loveIt)

        assertFeedback(
            sut.feedbackState,
            reaction: .loveIt,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
        #expect(homeChanges.isEmpty)
    }

    @Test("mutation failure keeps the last confirmed state and never notifies Home")
    func mutationFailureIsNonDestructive() async throws {
        let current = try state(
            watchState: .unwatched,
            watchlistIntent: WatchlistIntent(addedAt: .distantPast)
        )
        let updates = RecordingFeedbackUpdate(outcomes: [.failure])
        var homeChanges: [DecisionViewerStateChange] = []
        let sut = makeSUT(
            feedbackLoads: [.state(current)],
            updates: updates,
            viewerStateDidChange: { homeChanges.append($0) }
        )
        await sut.load()

        await sut.toggleWatched()

        assertFeedback(
            sut.feedbackState,
            reaction: nil,
            isWatched: false,
            isNotInterested: false,
            isInWatchlist: true,
            isSaving: false
        )
        #expect(sut.feedbackActionErrorMessage != nil)
        #expect(homeChanges.isEmpty)
    }

    @Test("only one explicit transition can be in flight")
    func concurrentActionsAreCoalesced() async throws {
        let gate = FeedbackOperationGate()
        let confirmed = try state(watchState: .watched)
        let change = ViewerMovieStateChange(
            state: confirmed,
            impact: .eligibilityChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let updates = RecordingFeedbackUpdate(
            outcomes: [.gated(gate, change)]
        )
        let sut = makeSUT(
            feedbackLoads: [.state(nil)],
            updates: updates
        )
        await sut.load()

        let first = Task { await sut.toggleWatched() }
        await updates.waitForCallCount(1)
        assertFeedback(
            sut.feedbackState,
            reaction: nil,
            isWatched: false,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: true
        )

        await sut.setReaction(.likeIt)
        #expect(await updates.transitions.count == 1)

        await gate.open()
        await first.value
    }

    @Test("cancelled mutation keeps confirmed state and publishes no failure or Home change")
    func cancelledMutationIsSilent() async throws {
        let current = try state(watchState: .watched)
        let gate = FeedbackOperationGate()
        let updates = RecordingFeedbackUpdate(outcomes: [.gatedCancellation(gate)])
        var homeChanges: [DecisionViewerStateChange] = []
        let sut = makeSUT(
            feedbackLoads: [.state(current)],
            updates: updates,
            viewerStateDidChange: { homeChanges.append($0) }
        )
        await sut.load()

        let action = Task { await sut.setReaction(.likeIt) }
        await updates.waitForCallCount(1)
        action.cancel()
        await gate.open()
        await action.value

        assertFeedback(
            sut.feedbackState,
            reaction: nil,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
        #expect(sut.feedbackActionErrorMessage == nil)
        #expect(homeChanges.isEmpty)
    }

    @Test("a committed mutation still publishes when caller cancellation races its return")
    func committedMutationWinsCancellationRace() async throws {
        let current = try state(watchState: .watched)
        let gate = FeedbackOperationGate()
        let changed = try state(
            watchState: .watched,
            preference: .reaction(.likeIt)
        )
        let update = ViewerMovieStateChange(
            state: changed,
            impact: .tasteChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let updates = RecordingFeedbackUpdate(outcomes: [.gated(gate, update)])
        var homeChanges: [DecisionViewerStateChange] = []
        let sut = makeSUT(
            feedbackLoads: [.state(current)],
            updates: updates,
            viewerStateDidChange: { homeChanges.append($0) }
        )
        await sut.load()

        let action = Task { await sut.setReaction(.likeIt) }
        await updates.waitForCallCount(1)
        action.cancel()
        await gate.open()
        await action.value

        assertFeedback(
            sut.feedbackState,
            reaction: .likeIt,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
        #expect(homeChanges.count == 1)
    }

    @Test("stale feedback load cannot overwrite a newer successful mutation")
    func staleFeedbackLoadCannotOverwriteMutation() async throws {
        let loadGate = FeedbackOperationGate()
        let changed = try state(
            watchState: .watched,
            preference: .reaction(.loveIt)
        )
        let update = ViewerMovieStateChange(
            state: changed,
            impact: .tasteChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let sut = makeSUT(
            feedbackLoads: [.gated(loadGate, nil)],
            updates: RecordingFeedbackUpdate(outcomes: [.change(update)])
        )

        let load = Task { await sut.load() }
        await waitForLoadedDetail(sut)
        await sut.setReaction(.loveIt)
        await loadGate.open()
        await load.value

        assertFeedback(
            sut.feedbackState,
            reaction: .loveIt,
            isWatched: true,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
    }

    @Test("offline mutation reuses persisted feedback metadata when detail is unavailable")
    func offlineMutationPreservesMetadata() async throws {
        let current = try state(
            watchState: .unwatched,
            preference: .notInterested,
            metadata: MovieFeedbackMetadata(
                title: "Stored offline title",
                releaseYear: 1999,
                posterPath: "/stored.jpg"
            )
        )
        let changed = ViewerMovieStateChange(
            state: nil,
            impact: .eligibilityChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let updates = RecordingFeedbackUpdate(outcomes: [.change(changed)])
        let sut = makeSUT(
            detail: FailingMovieDetailUseCase(),
            feedbackLoads: [.state(current)],
            updates: updates
        )
        await sut.load()

        await sut.toggleNotInterested()

        #expect(await updates.metadata == [current.displayMetadata])
        assertFeedback(
            sut.feedbackState,
            reaction: nil,
            isWatched: false,
            isNotInterested: false,
            isInWatchlist: false,
            isSaving: false
        )
    }

    @Test(
        "every feedback control maps to its accepted Domain transition",
        arguments: FeedbackActionCase.allCases
    )
    func controlsMapToTransitions(actionCase: FeedbackActionCase) async throws {
        let current = try actionCase.currentState.map {
            try state(
                watchState: $0.watchState,
                preference: $0.preference,
                watchlistIntent: $0.watchlistIntent
            )
        }
        let noOp = ViewerMovieStateChange(
            state: current,
            impact: .none,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
        let updates = RecordingFeedbackUpdate(outcomes: [.change(noOp)])
        let sut = makeSUT(
            feedbackLoads: [.state(current)],
            updates: updates
        )
        await sut.load()

        await actionCase.perform(on: sut)

        #expect(await updates.transitions == [ViewerMovieStateTransition(
            movieID: 42,
            action: actionCase.expectedAction
        )])
    }
}

private extension MovieDetailFeedbackViewModelTests {
    func makeSUT(
        detail: any GetMovieDetailUseCase = ImmediateFeedbackMovieDetailUseCase(),
        feedbackLoads: [FeedbackLoadOutcome],
        updates: RecordingFeedbackUpdate = RecordingFeedbackUpdate(outcomes: []),
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void = { _ in }
    ) -> MovieDetailViewModel {
        MovieDetailViewModel(
            movieId: 42,
            getMovieDetail: detail,
            getViewerMovieState: SequencedFeedbackLoad(outcomes: feedbackLoads),
            updateViewerMovieState: updates,
            checkAvailability: FeedbackUnknownAvailability(),
            preparePlaybackOptions: FeedbackUnavailablePlaybackOptions(),
            viewerStateDidChange: viewerStateDidChange
        )
    }

    func state(
        watchState: MovieWatchState,
        preference: MoviePreference? = nil,
        watchlistIntent: WatchlistIntent? = nil,
        metadata: MovieFeedbackMetadata? = nil
    ) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: 42,
            displayMetadata: metadata ?? detailMetadata(),
            watchState: watchState,
            preference: preference,
            watchlistIntent: watchlistIntent,
            stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func detailMetadata() throws -> MovieFeedbackMetadata {
        try MovieFeedbackMetadata(
            title: "Detail title",
            releaseYear: nil,
            posterPath: "/detail.jpg"
        )
    }

    func assertFeedback(
        _ state: MovieFeedbackViewState,
        reaction: MovieReaction?,
        isWatched: Bool,
        isNotInterested: Bool,
        isInWatchlist: Bool,
        isSaving: Bool
    ) {
        guard case let .loaded(model, actualIsSaving, _) = state else {
            Issue.record("Expected loaded feedback")
            return
        }
        #expect(model.reaction == reaction)
        #expect(model.isWatched == isWatched)
        #expect(model.isNotInterested == isNotInterested)
        #expect(model.isInWatchlist == isInWatchlist)
        #expect(actualIsSaving == isSaving)
    }

    func waitForLoadedDetail(_ sut: MovieDetailViewModel) async {
        for _ in 0 ..< 200 {
            if case .loaded = sut.state {
                return
            }
            await Task.yield()
        }
    }
}
