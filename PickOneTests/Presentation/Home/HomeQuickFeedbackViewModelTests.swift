import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("Home quick feedback", .serialized)
struct HomeQuickFeedbackViewModelTests {
    @Test(
        "every quick action uses the existing Viewer Movie State transition",
        arguments: HomeQuickFeedbackActionCase.allCases
    )
    func actionMapsToExistingTransition(actionCase: HomeQuickFeedbackActionCase) async throws {
        let update = RecordingHomeQuickFeedbackUpdate(outcomes: [.success(change(impact: .none))])
        let sut = try makeSUT(update: update)

        await sut.submit(actionCase.action)

        #expect(await update.transitions == [ViewerMovieStateTransition(
            movieID: 101,
            action: actionCase.action
        )])
        #expect(try await update.metadata == [metadata()])
    }

    @Test("progress is local to the card and does not block another card")
    func progressIsPerCard() async throws {
        let gate = HomeQuickFeedbackGate()
        let firstUpdate = RecordingHomeQuickFeedbackUpdate(outcomes: [
            .gated(gate, change(impact: .eligibilityChanged)),
        ])
        let secondUpdate = RecordingHomeQuickFeedbackUpdate(outcomes: [
            .success(change(impact: .eligibilityChanged)),
        ])
        let first = try makeSUT(update: firstUpdate)
        let second = try makeSUT(movieID: 202, update: secondUpdate)

        let firstTask = Task { await first.submit(.markWatched) }
        await firstUpdate.waitForCallCount(1)
        #expect(first.state == .saving)
        #expect(second.state == .idle)

        await second.submit(.setNotInterested)
        #expect(second.state == .submitted)

        await gate.open()
        await firstTask.value
        #expect(first.state == .submitted)
    }

    @Test("successful write hands the exact change to reconciliation after persistence")
    func successfulWriteHandsOffReconciliation() async throws {
        let expectedChange = change(impact: .tasteChanged)
        let gate = HomeQuickFeedbackGate()
        let update = RecordingHomeQuickFeedbackUpdate(outcomes: [
            .gated(gate, expectedChange),
        ])
        var receivedChanges: [DecisionViewerStateChange] = []
        let sut = try makeSUT(update: update) { receivedChanges.append($0) }

        let task = Task { await sut.submit(.assignReaction(.loveIt)) }
        await update.waitForCallCount(1)
        #expect(receivedChanges.isEmpty)
        #expect(sut.state == .saving)

        await gate.open()
        await task.value

        #expect(sut.state == .submitted)
        #expect(receivedChanges == [DecisionViewerStateChange(
            movieID: 101,
            impact: expectedChange.impact,
            snapshotID: expectedChange.snapshotID
        )])
    }

    @Test("failed write preserves retry intent and retry submits the same transition")
    func failureSupportsExactRetry() async throws {
        let expectedChange = change(impact: .eligibilityChanged)
        let update = RecordingHomeQuickFeedbackUpdate(outcomes: [
            .failure,
            .success(expectedChange),
        ])
        var receivedChanges: [DecisionViewerStateChange] = []
        let sut = try makeSUT(update: update) { receivedChanges.append($0) }

        await sut.submit(.markWatched)

        #expect(sut.state == .failed)
        #expect(receivedChanges.isEmpty)

        await sut.retry()

        #expect(sut.state == .submitted)
        #expect(await update.transitions.map(\.action) == [.markWatched, .markWatched])
        #expect(receivedChanges.count == 1)
    }

    @Test("cancel dismisses a failed write without changing Viewer Movie State")
    func cancelDismissesFailure() async throws {
        let update = RecordingHomeQuickFeedbackUpdate(outcomes: [.failure])
        let sut = try makeSUT(update: update)

        await sut.submit(.setNotInterested)
        sut.cancelFailure()

        #expect(sut.state == .idle)
        #expect(await update.transitions.count == 1)
    }

    @Test("cancelled write publishes neither success nor reconciliation")
    func cancellationIsSilent() async throws {
        let gate = HomeQuickFeedbackGate()
        let update = RecordingHomeQuickFeedbackUpdate(outcomes: [
            .gated(gate, change(impact: .eligibilityChanged)),
        ])
        var receivedChanges: [DecisionViewerStateChange] = []
        let sut = try makeSUT(update: update) { receivedChanges.append($0) }

        let task = Task { await sut.submit(.markWatched) }
        await update.waitForCallCount(1)
        task.cancel()
        await gate.open()
        await task.value

        #expect(sut.state == .idle)
        #expect(receivedChanges.isEmpty)
    }
}

private extension HomeQuickFeedbackViewModelTests {
    func makeSUT(
        movieID: Int = 101,
        update: RecordingHomeQuickFeedbackUpdate,
        viewerStateDidChange: @escaping @MainActor (DecisionViewerStateChange) -> Void = { _ in }
    ) throws -> HomeQuickFeedbackViewModel {
        try HomeQuickFeedbackViewModel(
            movieID: movieID,
            metadata: metadata(),
            updateViewerMovieState: update,
            viewerStateDidChange: viewerStateDidChange
        )
    }

    func metadata() throws -> MovieFeedbackMetadata {
        try MovieFeedbackMetadata(
            title: "Tonight's Movie",
            releaseYear: 2024,
            posterPath: "/poster.jpg"
        )
    }

    func change(impact: ViewerMovieStateChangeImpact) -> ViewerMovieStateChange {
        ViewerMovieStateChange(
            state: nil,
            impact: impact,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
    }
}

enum HomeQuickFeedbackActionCase: CaseIterable {
    case loveIt
    case likeIt
    case itWasOkay
    case didNotLikeIt
    case alreadyWatched
    case notInterested

    var action: ViewerMovieStateTransition.Action {
        switch self {
            case .loveIt: .assignReaction(.loveIt)
            case .likeIt: .assignReaction(.likeIt)
            case .itWasOkay: .assignReaction(.itWasOkay)
            case .didNotLikeIt: .assignReaction(.didNotLikeIt)
            case .alreadyWatched: .markWatched
            case .notInterested: .setNotInterested
        }
    }
}

private enum HomeQuickFeedbackUpdateOutcome: Sendable {
    case success(ViewerMovieStateChange)
    case gated(HomeQuickFeedbackGate, ViewerMovieStateChange)
    case failure
}

private actor RecordingHomeQuickFeedbackUpdate: UpdateViewerMovieStateUseCase {
    private var outcomes: [HomeQuickFeedbackUpdateOutcome]
    private(set) var transitions: [ViewerMovieStateTransition] = []
    private(set) var metadata: [MovieFeedbackMetadata] = []

    init(outcomes: [HomeQuickFeedbackUpdateOutcome]) {
        self.outcomes = outcomes
    }

    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange {
        transitions.append(transition)
        self.metadata.append(metadata)
        let outcome = outcomes.removeFirst()
        switch outcome {
            case let .success(change):
                return change
            case let .gated(gate, change):
                await gate.wait()
                return change
            case .failure:
                throw HomeQuickFeedbackTestError.writeFailed
        }
    }

    func waitForCallCount(_ expectedCount: Int) async {
        while transitions.count < expectedCount {
            await Task.yield()
        }
    }
}

private actor HomeQuickFeedbackGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }
}

private enum HomeQuickFeedbackTestError: Error {
    case writeFailed
}
