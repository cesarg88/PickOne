import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("HomeDecisionViewModel Tests", .serialized)
struct HomeDecisionViewModelTests {
    @Test("load maps a usable set and an honest empty set")
    func loadMapsUsableStates() async throws {
        let populated = try HomeDecisionTestFixtures.snapshot()
        let empty = try HomeDecisionTestFixtures.snapshot(recommendations: [])
        let useCase = HomeDecisionUseCase(results: [
            .success(.usable(populated)),
            .success(.usable(empty)),
        ])
        let sut = HomeDecisionViewModel(threeForTonight: useCase)

        sut.load()
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)
        guard case let .loaded(set, isRefreshing, refreshError) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(set.items.map(\.id) == [101])
        #expect(!isRefreshing)
        #expect(refreshError == nil)

        sut.load()
        await useCase.waitForCallCount(2)
        await waitUntilSettled(sut)
        guard case let .empty(isRefreshing, refreshError) = sut.state else {
            Issue.record("Expected honest empty state")
            return
        }
        #expect(!isRefreshing)
        #expect(refreshError == nil)
    }

    @Test("refresh keeps usable content and decorates a non-destructive failure")
    func refreshRetainsContentOnFailure() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = HomeDecisionUseCase(results: [
            .success(.usable(snapshot)),
            .success(.retryableFailure(reason: .generationUnavailable, retained: snapshot)),
        ])
        let sut = HomeDecisionViewModel(threeForTonight: useCase)
        sut.load()
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)

        sut.refresh()
        guard case let .loaded(_, isRefreshing, _) = sut.state else {
            Issue.record("Expected retained loaded state while refreshing")
            return
        }
        #expect(isRefreshing)
        await useCase.waitForCallCount(2)
        await waitUntilSettled(sut)

        guard case let .loaded(set, isRefreshing, refreshError) = sut.state else {
            Issue.record("Expected retained loaded state after failure")
            return
        }
        #expect(set.items.map(\.id) == [101])
        #expect(!isRefreshing)
        #expect(refreshError == "Couldn't update tonight's picks. Please try again.")
    }

    @Test("eligibility change invokes the bounded repair operation")
    func eligibilityChangeInvokesRepair() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = HomeDecisionUseCase(results: [.success(.usable(snapshot))])
        let sut = HomeDecisionViewModel(threeForTonight: useCase)
        let change = try #require(DecisionEligibilityChange(movieID: 101, cause: .watchlist))

        sut.repair(after: change)
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)

        #expect(await useCase.recordedRepairs() == [change])
    }

    @Test("successful reconciliation shows transient feedback only after publication")
    func successfulReconciliationShowsTransientFeedback() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let gate = HomeDecisionOperationGate()
        let useCase = GatedHomeDecisionUseCase(
            loadResult: .usable(snapshot),
            repairResult: .usable(snapshot),
            gate: gate
        )
        let sut = HomeDecisionViewModel(
            threeForTonight: useCase,
            feedbackDuration: .milliseconds(20)
        )
        let change = try #require(
            DecisionEligibilityChange(movieID: 101, cause: .watchlist)
        )

        sut.repair(after: change)
        await useCase.waitForRepairStart()
        #expect(sut.updateFeedback == nil)

        await gate.open()
        await waitForUpdateFeedback(in: sut)
        #expect(sut.updateFeedback == "Recommendations updated.")

        await waitForUpdateFeedbackDismissal(in: sut)
        #expect(sut.updateFeedback == nil)
    }

    @Test("a published queued snapshot is coalesced into one Home update")
    func publishedQueuedSnapshotIsCoalesced() async throws {
        let published = try HomeDecisionTestFixtures.snapshot()
        let gate = HomeDecisionOperationGate()
        let useCase = GatedHomeDecisionUseCase(
            loadResult: .usable(published),
            repairResult: .usable(published),
            gate: gate
        )
        let sut = HomeDecisionViewModel(
            threeForTonight: useCase,
            feedbackDuration: .milliseconds(20)
        )
        let activeChange = try #require(DecisionViewerStateChange(
            movieID: 201,
            impact: .tasteChanged,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        ))
        let queuedChange = try #require(DecisionViewerStateChange(
            movieID: 202,
            impact: .tasteChanged,
            snapshotID: published.decisionSet.sourceViewerStateSnapshotID
        ))

        sut.reconcile(after: activeChange)
        await useCase.waitForRepairStart()
        sut.reconcile(after: queuedChange)
        await gate.open()
        await waitForUpdateFeedback(in: sut)
        await waitUntilSettled(sut)

        #expect(await useCase.recordedViewerChanges() == [activeChange])
        #expect(sut.updateFeedback == "Recommendations updated.")

        await waitForUpdateFeedbackDismissal(in: sut)
        #expect(sut.updateFeedback == nil)
        #expect(await useCase.recordedViewerChanges() == [activeChange])
    }

    @Test("failed reconciliation and semantic no-op show no update feedback")
    func unsuccessfulOrNoOpReconciliationShowsNoFeedback() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = HomeDecisionUseCase(results: [
            .success(.retryableFailure(reason: .repairFailed, retained: snapshot)),
        ])
        let sut = HomeDecisionViewModel(threeForTonight: useCase)
        let repair = try #require(
            DecisionEligibilityChange(movieID: 101, cause: .watchlist)
        )

        sut.repair(after: repair)
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)
        #expect(sut.updateFeedback == nil)

        let noOp = try #require(DecisionViewerStateChange(
            movieID: 101,
            impact: .none,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        ))
        sut.reconcile(after: noOp)
        await Task.yield()

        #expect(await useCase.recordedCallCount() == 1)
        #expect(sut.updateFeedback == nil)
    }

    @Test("blocking failure retries into usable content")
    func blockingFailureRetries() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let useCase = HomeDecisionUseCase(results: [
            .success(.retryableFailure(reason: .generationUnavailable, retained: nil)),
            .success(.usable(snapshot)),
        ])
        let sut = HomeDecisionViewModel(threeForTonight: useCase)

        sut.load()
        await useCase.waitForCallCount(1)
        await waitUntilSettled(sut)
        #expect(
            sut.state == .failure("Tonight's picks couldn't be loaded. Please try again.")
        )

        sut.load()
        #expect(sut.state == .loading)
        await useCase.waitForCallCount(2)
        await waitUntilSettled(sut)

        guard case let .loaded(set, isRefreshing, refreshError) = sut.state else {
            Issue.record("Expected Retry to publish usable content")
            return
        }
        #expect(set.items.map(\.id) == [101])
        #expect(!isRefreshing)
        #expect(refreshError == nil)
    }

    @Test("repair survives Home activation and return reconciliation")
    func repairSurvivesPassiveLoad() async throws {
        let reconciled = try HomeDecisionTestFixtures.snapshot(
            recommendations: [
                HomeDecisionTestFixtures.recommendation(movieID: 303),
            ]
        )
        let repaired = try HomeDecisionTestFixtures.snapshot(
            recommendations: [
                HomeDecisionTestFixtures.recommendation(movieID: 202),
            ]
        )
        let gate = HomeDecisionOperationGate()
        let useCase = GatedHomeDecisionUseCase(
            loadResult: .usable(reconciled),
            repairResult: .usable(repaired),
            gate: gate
        )
        let sut = HomeDecisionViewModel(threeForTonight: useCase)
        let change = try #require(
            DecisionEligibilityChange(movieID: 101, cause: .availability)
        )

        sut.repair(after: change)
        await useCase.waitForRepairStart()
        sut.load()
        let loadStartedBeforeRepairFinished = await useCase.waitForLoadStart()
        await gate.open()
        let loadStartedAfterRepairFinished = await useCase.waitForLoadStart()

        #expect(!loadStartedBeforeRepairFinished)
        #expect(loadStartedAfterRepairFinished)
        #expect(await useCase.recordedRepairs() == [change])
        await waitForItems([303], in: sut)
        guard case let .loaded(set, _, _) = sut.state else {
            Issue.record("Expected reconciled content")
            return
        }
        #expect(set.items.map(\.id) == [303])
    }

    @Test("load requested during refresh reconciles its older trusted-input snapshot")
    func loadRequestedDuringRefreshIsPreserved() async throws {
        let refreshed = try HomeDecisionTestFixtures.snapshot(
            recommendations: [
                HomeDecisionTestFixtures.recommendation(movieID: 202),
            ]
        )
        let reconciled = try HomeDecisionTestFixtures.snapshot(
            recommendations: [
                HomeDecisionTestFixtures.recommendation(movieID: 303),
            ]
        )
        let gate = HomeDecisionOperationGate()
        let useCase = GatedHomeDecisionUseCase(
            loadResult: .usable(reconciled),
            refreshResult: .usable(refreshed),
            repairResult: .usable(refreshed),
            gate: gate
        )
        let sut = HomeDecisionViewModel(threeForTonight: useCase)

        sut.refresh()
        await useCase.waitForRefreshStart()
        sut.load()
        let loadStartedBeforeRefreshFinished = await useCase.waitForLoadStart()
        await gate.open()
        let loadStartedAfterRefreshFinished = await useCase.waitForLoadStart()
        await waitForItems([303], in: sut)

        #expect(!loadStartedBeforeRefreshFinished)
        #expect(loadStartedAfterRefreshFinished)
        guard case let .loaded(set, _, _) = sut.state else {
            Issue.record("Expected reconciled content")
            return
        }
        #expect(set.items.map(\.id) == [303])
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

    private func waitForItems(
        _ expectedIDs: [Int],
        in sut: HomeDecisionViewModel
    ) async {
        for _ in 0 ..< 100 {
            if case let .loaded(set, _, _) = sut.state,
               set.items.map(\.id) == expectedIDs
            {
                return
            }
            await Task.yield()
        }
    }

    private func waitForUpdateFeedback(
        in sut: HomeDecisionViewModel
    ) async {
        for _ in 0 ..< 100 where sut.updateFeedback == nil {
            await Task.yield()
        }
    }

    private func waitForUpdateFeedbackDismissal(
        in sut: HomeDecisionViewModel
    ) async {
        for _ in 0 ..< 100 where sut.updateFeedback != nil {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }
}

private actor HomeDecisionOperationGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }
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

private actor GatedHomeDecisionUseCase: ThreeForTonightUseCase {
    private let loadResult: ThreeForTonightResult
    private let refreshResult: ThreeForTonightResult?
    private let repairResult: ThreeForTonightResult
    private let gate: HomeDecisionOperationGate
    private var loadCallCount = 0
    private var refreshStarted = false
    private var repairStarted = false
    private var repairs: [DecisionEligibilityChange] = []
    private var viewerChanges: [DecisionViewerStateChange] = []

    init(
        loadResult: ThreeForTonightResult,
        refreshResult: ThreeForTonightResult? = nil,
        repairResult: ThreeForTonightResult,
        gate: HomeDecisionOperationGate
    ) {
        self.loadResult = loadResult
        self.refreshResult = refreshResult
        self.repairResult = repairResult
        self.gate = gate
    }

    func load() async throws -> ThreeForTonightResult {
        loadCallCount += 1
        return loadResult
    }

    func refresh() async throws -> ThreeForTonightResult {
        guard let refreshResult else { return loadResult }
        refreshStarted = true
        await gate.wait()
        try Task.checkCancellation()
        return refreshResult
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        repairs.append(change)
        repairStarted = true
        await gate.wait()
        try Task.checkCancellation()
        return repairResult
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        viewerChanges.append(change)
        repairStarted = true
        await gate.wait()
        try Task.checkCancellation()
        return repairResult
    }

    func waitForRepairStart() async {
        while !repairStarted {
            await Task.yield()
        }
    }

    func waitForRefreshStart() async {
        while !refreshStarted {
            await Task.yield()
        }
    }

    func waitForLoadStart() async -> Bool {
        for _ in 0 ..< 200 {
            if loadCallCount > 0 {
                return true
            }
            await Task.yield()
        }
        return false
    }

    func recordedRepairs() -> [DecisionEligibilityChange] {
        repairs
    }

    func recordedViewerChanges() -> [DecisionViewerStateChange] {
        viewerChanges
    }
}

private actor HomeDecisionUseCase: ThreeForTonightUseCase {
    private var results: [Result<ThreeForTonightResult, Error>]
    private var callCount = 0
    private var repairs: [DecisionEligibilityChange] = []

    init(results: [Result<ThreeForTonightResult, Error>]) {
        self.results = results
    }

    func load() async throws -> ThreeForTonightResult {
        try nextResult()
    }

    func refresh() async throws -> ThreeForTonightResult {
        try nextResult()
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        repairs.append(change)
        return try nextResult()
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        guard let repair = DecisionEligibilityChange(
            movieID: change.movieID,
            cause: .watchlist
        ) else {
            throw HomeDecisionTestError.missingResult
        }
        repairs.append(repair)
        return try nextResult()
    }

    func waitForCallCount(_ expectedCount: Int) async {
        while callCount < expectedCount {
            await Task.yield()
        }
    }

    func recordedRepairs() -> [DecisionEligibilityChange] {
        repairs
    }

    func recordedCallCount() -> Int {
        callCount
    }

    private func nextResult() throws -> ThreeForTonightResult {
        callCount += 1
        guard !results.isEmpty else {
            throw HomeDecisionTestError.missingResult
        }
        return try results.removeFirst().get()
    }
}

private enum HomeDecisionTestError: Error {
    case missingResult
}
