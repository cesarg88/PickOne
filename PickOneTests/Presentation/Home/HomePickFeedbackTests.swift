import Foundation
@testable import PickOne
import Testing

@MainActor
struct HomePickFeedbackTests {
    @Test func dismissalPreservesDurablePickAndDoesNotReplayOnHomeReturnOrRelaunch() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let delay = HomeFeedbackTestDelay()
        let model = HomePickViewModel(
            manage: ManageViewingDecision(repository: repository),
            clock: PickTestClock().now,
            feedbackSleep: delay.sleep
        )
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        model.pick(movieID: 1)
        await model.waitForPendingOperations()
        let decision = try #require(model.activeDecision)
        #expect(model.isShowingPickFeedback)
        await delay.waitForRequestCount(1)
        #expect(await delay.requestedDurations() == [.seconds(3)])
        await delay.resumeAll()
        await waitForDismissal(model)
        #expect(!model.isShowingPickFeedback)
        #expect(model.activeDecision == decision)
        #expect(try await repository.snapshot().activeDecision == decision)

        model.hideSurface()
        model.showHome()
        await model.waitForPendingOperations()
        #expect(!model.isShowingPickFeedback)
        let restored = HomePickViewModel(manage: ManageViewingDecision(
            repository: LocalViewingDecisionRepository(store: store)
        ), clock: PickTestClock().now)
        restored.showHome()
        restored.setActive(true)
        await restored.waitForPendingOperations()
        #expect(restored.activeDecision == decision)
        #expect(!restored.isShowingPickFeedback)
        // Cancellation remains a separate explicit action after the acknowledgment disappears.
        restored.cancel()
        await restored.waitForPendingOperations()
        #expect(restored.activeDecision == nil)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().activeDecision == nil)
    }

    @Test func failedSaveShowsNoSuccessNoticeAndRetryStartsItsOwnDismissal() async throws {
        let store = MemoryViewingDecisionStore()
        let delay = HomeFeedbackTestDelay()
        let model = HomePickViewModel(
            manage: ManageViewingDecision(repository: LocalViewingDecisionRepository(store: store)),
            feedbackSleep: delay.sleep
        )
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        await model.waitForPendingOperations()
        store.failure = "active"
        model.pick(movieID: 1)
        await model.waitForPendingOperations()
        #expect(!model.isShowingPickFeedback)
        #expect(await delay.requestedDurations().isEmpty)
        store.failure = nil
        model.retry(movieID: 1)
        await model.waitForPendingOperations()
        #expect(model.isShowingPickFeedback)
        await delay.waitForRequestCount(1)
        await delay.resumeAll()
        await waitForDismissal(model)
        #expect(!model.isShowingPickFeedback)
        #expect(model.activeDecision?.recommendation.movieID == 1)
    }

    @Test func replacingPickGetsFreshNoticeAndCancellationClearsItImmediately() async throws {
        let delay = PickFeedbackTestDelay()
        let model = HomePickViewModel(
            manage: ManageViewingDecision(
                repository: LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
            ),
            feedbackSleep: delay.sleep
        )
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        model.pick(movieID: 1)
        await model.waitForPendingOperations()
        await delay.waitForRequestCount(1)
        model.pick(movieID: 2)
        await model.waitForPendingOperations()
        await delay.waitForRequestCount(2)
        await delay.resumeFirst()
        for _ in 0 ..< 200 {
            await Task.yield()
        }
        #expect(model.isShowingPickFeedback, "An older deadline must not dismiss the replacement's notice")
        #expect(model.activeDecision?.recommendation.movieID == 2)
        model.cancel()
        await model.waitForPendingOperations()
        #expect(!model.isShowingPickFeedback)
        #expect(model.activeDecision == nil)
        await delay.resumeFirst()
    }

    private func waitForDismissal(_ model: HomePickViewModel) async {
        for _ in 0 ..< 200 where model.isShowingPickFeedback {
            await Task.yield()
        }
    }
}

private actor PickFeedbackTestDelay {
    private var requests = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for _: Duration) async throws {
        requests += 1
        await withCheckedContinuation { waiters.append($0) }
        // Deliberately ignore cancellation here to exercise the view model's stale-task guard.
    }

    func waitForRequestCount(_ count: Int) async {
        while requests < count {
            await Task.yield()
        }
    }

    func resumeFirst() {
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().resume()
    }
}
