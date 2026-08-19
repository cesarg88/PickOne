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
        let original = try HomeDecisionTestFixtures.snapshot()
        let repaired = try HomeDecisionTestFixtures.snapshot(
            recommendations: [
                HomeDecisionTestFixtures.recommendation(movieID: 202),
            ]
        )
        let gate = HomeDecisionOperationGate()
        let useCase = GatedRepairHomeDecisionUseCase(
            loadResult: .usable(original),
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
        let passiveLoadStarted = await useCase.waitForLoadStart()
        await gate.open()
        await waitUntilSettled(sut)

        #expect(!passiveLoadStarted)
        #expect(await useCase.recordedRepairs() == [change])
        guard case let .loaded(set, _, _) = sut.state else {
            Issue.record("Expected repaired content")
            return
        }
        #expect(set.items.map(\.id) == [202])
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

private actor GatedRepairHomeDecisionUseCase: ThreeForTonightUseCase {
    private let loadResult: ThreeForTonightResult
    private let repairResult: ThreeForTonightResult
    private let gate: HomeDecisionOperationGate
    private var loadCallCount = 0
    private var repairStarted = false
    private var repairs: [DecisionEligibilityChange] = []

    init(
        loadResult: ThreeForTonightResult,
        repairResult: ThreeForTonightResult,
        gate: HomeDecisionOperationGate
    ) {
        self.loadResult = loadResult
        self.repairResult = repairResult
        self.gate = gate
    }

    func load() async throws -> ThreeForTonightResult {
        loadCallCount += 1
        return loadResult
    }

    func refresh() async throws -> ThreeForTonightResult {
        loadResult
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

    func waitForRepairStart() async {
        while !repairStarted {
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

    func waitForCallCount(_ expectedCount: Int) async {
        while callCount < expectedCount {
            await Task.yield()
        }
    }

    func recordedRepairs() -> [DecisionEligibilityChange] {
        repairs
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
