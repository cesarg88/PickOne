import Foundation
@testable import PickOne
import Synchronization
import Testing

@MainActor
@Suite("Home exhaustion presentation", .serialized)
struct HomeDecisionExhaustionViewModelTests {
    @Test("fresh exhaustion blocks refresh until its visible deadline expires")
    func deadlineRestoresExplicitRefresh() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot(recommendations: [])
        let startedAt = Date(timeIntervalSince1970: 1000)
        let expiresAt = startedAt.addingTimeInterval(24 * 60 * 60)
        let clock = HomeExhaustionTestClock(now: startedAt)
        let delay = HomeFeedbackTestDelay()
        let useCase = HomeExhaustionUseCase(results: [
            .exhausted(ThreeForTonightExhaustion(
                snapshot: snapshot,
                expiresAt: expiresAt,
                canRefresh: false
            )),
            .usable(snapshot),
        ])
        let sut = HomeDecisionViewModel(
            threeForTonight: useCase,
            now: clock.now,
            exhaustionSleep: delay.sleep
        )

        sut.homeDidAppear()
        sut.load()
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)
        await delay.waitForRequestCount(1)
        #expect(sut.exhaustion == HomeDecisionExhaustionPresentation(
            recommendationCount: 0,
            expiresAt: expiresAt,
            canRefresh: false
        ))

        sut.refresh()
        await Task.yield()
        #expect(await useCase.callCount == 1)

        clock.setNow(expiresAt)
        await delay.resumeAll()
        for _ in 0 ..< 100 where sut.exhaustion?.canRefresh != true {
            await Task.yield()
        }
        #expect(sut.exhaustion?.canRefresh == true)

        sut.refresh()
        await useCase.waitForCallCount(2)
        await waitUntilSettled(sut)
        #expect(await useCase.callCount == 2)
        #expect(sut.exhaustion == nil)
    }

    @Test("retryable failure never remains presented as exhaustion")
    func failureRestoresRetryControls() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = HomeExhaustionUseCase(results: [
            .exhausted(ThreeForTonightExhaustion(
                snapshot: snapshot,
                expiresAt: .distantPast,
                canRefresh: true
            )),
            .retryableFailure(
                reason: .generationUnavailable,
                retained: snapshot
            ),
        ])
        let sut = HomeDecisionViewModel(threeForTonight: useCase)

        sut.load()
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)
        sut.refresh()
        await useCase.waitForCallCount(2)
        await waitUntilSettled(sut)

        #expect(sut.exhaustion == nil)
        guard case let .loaded(_, _, refreshError) = sut.state else {
            Issue.record("Expected retained content with Retry")
            return
        }
        #expect(refreshError == "Couldn't update tonight's picks. Please try again.")
    }

    private func waitUntilSettled(_ sut: HomeDecisionViewModel) async {
        for _ in 0 ..< 100 {
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
}

private final class HomeExhaustionTestClock: Sendable {
    private let value: Mutex<Date>

    init(now: Date) {
        value = Mutex(now)
    }

    func now() -> Date {
        value.withLock { $0 }
    }

    func setNow(_ now: Date) {
        value.withLock { $0 = now }
    }
}

private actor HomeExhaustionUseCase: ThreeForTonightUseCase {
    private var results: [ThreeForTonightResult]
    private(set) var callCount = 0

    init(results: [ThreeForTonightResult]) {
        self.results = results
    }

    func load() throws -> ThreeForTonightResult {
        try nextResult()
    }

    func refresh() throws -> ThreeForTonightResult {
        try nextResult()
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) throws -> ThreeForTonightResult {
        try nextResult()
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) throws -> ThreeForTonightResult {
        try nextResult()
    }

    func waitForCallCount(_ expectedCount: Int) async {
        while callCount < expectedCount {
            await Task.yield()
        }
    }

    private func nextResult() throws -> ThreeForTonightResult {
        callCount += 1
        guard !results.isEmpty else { throw HomeExhaustionTestError.missingResult }
        return results.removeFirst()
    }
}

private enum HomeExhaustionTestError: Error {
    case missingResult
}
