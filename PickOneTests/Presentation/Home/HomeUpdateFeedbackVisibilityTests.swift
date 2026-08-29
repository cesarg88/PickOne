import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("Home update feedback visibility", .serialized)
struct HomeUpdateFeedbackVisibilityTests {
    @Test("an inactive Home presents pending feedback only after becoming visible")
    func inactivePublicationWaitsForVisibilityAndDismissesAfterPresentation() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let operationGate = HomeFeedbackOperationGate()
        let delay = HomeFeedbackTestDelay()
        let useCase = VisibilityAwareHomeUseCase(
            result: .usable(snapshot),
            gate: operationGate
        )
        let sut = HomeDecisionViewModel(
            threeForTonight: useCase,
            feedbackDuration: .seconds(3),
            feedbackSleep: delay.sleep
        )
        let change = try #require(
            DecisionEligibilityChange(movieID: 101, cause: .watchlist)
        )

        sut.homeDidDisappear()
        sut.repair(after: change)
        await useCase.waitUntilStarted()
        #expect(sut.updateFeedback == nil)
        #expect(await delay.requestedDurations().isEmpty)

        await operationGate.open()
        await waitUntilSettled(sut)
        #expect(sut.updateFeedback == nil)
        #expect(await delay.requestedDurations().isEmpty)

        sut.homeDidAppear()
        #expect(sut.updateFeedback == "Recommendations updated.")
        await delay.waitForRequestCount(1)
        #expect(await delay.requestedDurations() == [.seconds(3)])

        await delay.resumeAll()
        await waitForFeedbackDismissal(sut)
        #expect(sut.updateFeedback == nil)
    }

    @Test("leaving Home preserves visible feedback for the next appearance")
    func leavingHomePreservesFeedback() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let operationGate = HomeFeedbackOperationGate()
        let delay = HomeFeedbackTestDelay()
        let useCase = VisibilityAwareHomeUseCase(
            result: .usable(snapshot),
            gate: operationGate
        )
        let sut = HomeDecisionViewModel(
            threeForTonight: useCase,
            feedbackDuration: .seconds(3),
            feedbackSleep: delay.sleep
        )
        let change = try #require(
            DecisionEligibilityChange(movieID: 101, cause: .watchlist)
        )

        sut.homeDidAppear()
        sut.repair(after: change)
        await useCase.waitUntilStarted()
        await operationGate.open()
        await waitForFeedbackPresentation(sut)
        await delay.waitForRequestCount(1)

        sut.homeDidDisappear()
        #expect(sut.updateFeedback == nil)

        sut.homeDidAppear()
        #expect(sut.updateFeedback == "Recommendations updated.")
        await delay.waitForRequestCount(2)
        #expect(await delay.requestedDurations() == [.seconds(3), .seconds(3)])

        await delay.resumeAll()
        await waitForFeedbackDismissal(sut)
        #expect(sut.updateFeedback == nil)
    }

    private func waitUntilSettled(_ sut: HomeDecisionViewModel) async {
        for _ in 0 ..< 200 {
            switch sut.state {
                case .loading:
                    await Task.yield()
                case let .loaded(_, isRefreshing, _) where isRefreshing:
                    await Task.yield()
                case let .empty(isRefreshing, _) where isRefreshing:
                    await Task.yield()
                default:
                    return
            }
        }
    }

    private func waitForFeedbackPresentation(_ sut: HomeDecisionViewModel) async {
        for _ in 0 ..< 200 where sut.updateFeedback == nil {
            await Task.yield()
        }
    }

    private func waitForFeedbackDismissal(_ sut: HomeDecisionViewModel) async {
        for _ in 0 ..< 200 where sut.updateFeedback != nil {
            await Task.yield()
        }
    }
}

actor HomeFeedbackTestDelay {
    private var durations: [Duration] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws {
        durations.append(duration)
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        try Task.checkCancellation()
    }

    func waitForRequestCount(_ count: Int) async {
        while durations.count < count {
            await Task.yield()
        }
    }

    func requestedDurations() -> [Duration] {
        durations
    }

    func resumeAll() {
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }
}

private actor HomeFeedbackOperationGate {
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

private actor VisibilityAwareHomeUseCase: ThreeForTonightUseCase {
    private let result: ThreeForTonightResult
    private let gate: HomeFeedbackOperationGate
    private var hasStarted = false

    init(
        result: ThreeForTonightResult,
        gate: HomeFeedbackOperationGate
    ) {
        self.result = result
        self.gate = gate
    }

    func load() -> ThreeForTonightResult {
        result
    }

    func refresh() -> ThreeForTonightResult {
        result
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        try await reconcile()
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        try await reconcile()
    }

    func waitUntilStarted() async {
        while !hasStarted {
            await Task.yield()
        }
    }

    private func reconcile() async throws -> ThreeForTonightResult {
        hasStarted = true
        await gate.wait()
        try Task.checkCancellation()
        return result
    }
}
