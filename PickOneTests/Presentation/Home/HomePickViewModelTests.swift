import Foundation
@testable import PickOne
import Synchronization
import Testing

@MainActor
struct HomePickViewModelTests {
    @Test func immediateFeedbackWaitsForObservationAndKeepsOriginalSession() async throws {
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let clock = PickTestClock()
        let model = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: clock.now)
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        let record = model.alreadyWatchedRecorder(movieID: 1)
        record()
        await model.waitForPendingOperations()
        #expect(try await repository.snapshot().sessions.first?.alreadyWatchedMovieIDs == [1])
        let delayedRecord = model.alreadyWatchedRecorder(movieID: 2)
        clock.seconds = 2000
        model.showHome()
        await model.waitForPendingOperations()
        delayedRecord()
        await model.waitForPendingOperations()
        let sessions = try await repository.snapshot().sessions
        #expect(sessions.count == 2)
        #expect(sessions.first?.alreadyWatchedMovieIDs == [1, 2])
        #expect(sessions.last?.alreadyWatchedMovieIDs.isEmpty == true)
    }

    @Test func feedbackAfterInactivityObservesTheStillVisibleHome() async throws {
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let clock = PickTestClock()
        let model = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: clock.now)
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        await model.waitForPendingOperations()
        clock.seconds = 2000
        _ = try await repository.apply(.init(action: .expire, moment: clock.now()))
        model.alreadyWatchedRecorder(movieID: 1)()
        await model.waitForPendingOperations()
        let sessions = try await repository.snapshot().sessions
        #expect(sessions.count == 2)
        #expect(sessions.last?.alreadyWatchedMovieIDs == [1])
    }

    @Test func perCardFailureRetryAndReplacementPublishOnlyDurableSuccess() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let clock = PickTestClock()
        let model = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: clock.now)
        let surface = try ViewingDecisionTestFixtures.surface()
        model.updateSurface(surface)
        model.showHome()
        model.setActive(true)
        await model.waitForPendingOperations()
        clock.seconds = 10
        store.failure = "active"
        model.pick(movieID: 1)
        #expect(model.savingMovieIDs == [1])
        #expect(model.activeDecision == nil)
        await model.waitForPendingOperations()
        #expect(model.failedMovieIDs == [1])
        #expect(model.savingMovieIDs.isEmpty)
        #expect(model.activeDecision == nil)
        store.failure = nil
        model.retry(movieID: 1)
        await model.waitForPendingOperations()
        #expect(model.activeDecision?.recommendation.movieID == 1)
        #expect(model.failedMovieIDs.isEmpty)
        clock.seconds = 20
        model.pick(movieID: 2)
        await model.waitForPendingOperations()
        #expect(model.activeDecision?.recommendation.movieID == 2)
        #expect(try await repository.snapshot().decisions.first?.status == .superseded)
        model.cancel()
        await model.waitForPendingOperations()
        #expect(model.activeDecision == nil)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().decisions.last?.status == .cancelled)
    }

    @Test func delayedCompletionsCannotReplaceNewerChoice() async throws {
        let repository = GatedViewingDecisionRepository()
        let clock = PickTestClock()
        let model = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: clock.now)
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        await model.waitForPendingOperations()
        clock.seconds = 10
        model.pick(movieID: 1)
        await repository.waitForPick()
        clock.seconds = 20
        model.pick(movieID: 2)
        #expect(model.savingMovieIDs == [1, 2])
        #expect(model.activeDecision == nil)
        await repository.release()
        await model.waitForPendingOperations()
        #expect(model.activeDecision?.recommendation.movieID == 2)
        #expect(try await repository.snapshot().decisions.map(\.status) == [.superseded, .active])
    }

    @Test func oldFailedRetryCannotUndoLaterPickOrCancellation() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let clock = PickTestClock()
        let model = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: clock.now)
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        model.showHome()
        model.setActive(true)
        await model.waitForPendingOperations()
        store.failure = "active"
        clock.seconds = 10
        model.pick(movieID: 1)
        await model.waitForPendingOperations()
        store.failure = nil
        clock.seconds = 20
        model.pick(movieID: 2)
        await model.waitForPendingOperations()
        model.retry(movieID: 1)
        await model.waitForPendingOperations()
        #expect(model.activeDecision?.recommendation.movieID == 2)
        clock.seconds = 30
        model.cancel()
        await model.waitForPendingOperations()
        model.retry(movieID: 1)
        await model.waitForPendingOperations()
        #expect(model.activeDecision == nil)
    }

    @Test func relatedDetailRemainsVisibleThroughBackgroundAndOldSetBoundary() async throws {
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let clock = PickTestClock()
        let model = HomePickViewModel(manage: ManageViewingDecision(repository: repository), clock: clock.now)
        let surface = try ViewingDecisionTestFixtures.surface()
        model.updateSurface(surface)
        model.showHome()
        model.setActive(true)
        await model.waitForPendingOperations()
        clock.seconds = 10
        model.showRelatedDetail(movieID: 1)
        clock.seconds = 20
        model.setActive(false)
        clock.seconds = 100
        model.setActive(true)
        await model.waitForPendingOperations()
        #expect(try await repository.snapshot().sessions.count == 1)
        #expect(try await repository.snapshot().openSession?.foregroundDuration == 20)
        clock.seconds = 2000
        model.setActive(false)
        clock.seconds = 2010
        model.setActive(true)
        await model.waitForPendingOperations()
        #expect(try await repository.snapshot().sessions.count == 2)
        #expect(try await repository.snapshot().openSession?.observedMovieIDs == [1])
        #expect(try await repository.snapshot().openSession?.observedSetIDs == surface.recommendations.first
            .map { [$0.setID] })
        model.hideSurface()
        try model.updateSurface(ViewingDecisionTestFixtures.surface())
        await model.waitForPendingOperations()
        #expect(try await repository.snapshot().openSession?.observedSetIDs.count == 1)
    }

    @Test func homePickDoesNotInvokeRecommendationGenerationOrMutatePublishedSet() async throws {
        let snapshot = try HomeDecisionTestFixtures.snapshot()
        let homeUseCase = PickHomeUseCase(snapshot: snapshot)
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let pickModel = HomePickViewModel(manage: ManageViewingDecision(repository: repository))
        let home = HomeDecisionViewModel(threeForTonight: homeUseCase, pickModel: pickModel)
        home.load()
        for _ in 0 ..< 1000 {
            if case .loaded = home.state { break }
            await Task.yield()
        }
        guard case .loaded = home.state else { Issue.record("Home did not load"); return }
        let before = home.state
        pickModel.showHome()
        pickModel.setActive(true)
        pickModel.pick(movieID: 101)
        await pickModel.waitForPendingOperations()
        #expect(pickModel.activeDecision?.recommendation.movieID == 101)
        #expect(home.state == before)
        #expect(await homeUseCase.calls == 1)
        // The Pick graph has no Viewer Movie State, availability, or Decision Set mutation dependency.
    }
}

final class PickTestClock: Sendable {
    private let value = Mutex(0.0)
    var seconds: Double {
        get { value.withLock { $0 } } set { value.withLock { $0 = newValue } }
    }

    func now() -> DecisionMoment {
        ViewingDecisionTestFixtures.moment(seconds)
    }
}

private actor GatedViewingDecisionRepository: ViewingDecisionRepository {
    private let base = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
    private var gate: CheckedContinuation<Void, Never>?
    private var didStartPick = false
    private var shouldGate = true
    func snapshot() async throws -> ViewingDecisionState {
        try await base.snapshot()
    }

    func apply(_ operation: ViewingDecisionOperation) async throws -> ViewingDecisionReceipt {
        if case .pick = operation.action, shouldGate {
            shouldGate = false
            didStartPick = true
            await withCheckedContinuation { gate = $0 }
        }
        return try await base.apply(operation)
    }

    func waitForPick() async {
        while !didStartPick {
            await Task.yield()
        }
    }

    func release() {
        gate?.resume(); gate = nil
    }
}

private actor PickHomeUseCase: ThreeForTonightUseCase {
    let snapshot: ThreeForTonightSnapshot
    private(set) var calls = 0
    init(snapshot: ThreeForTonightSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> ThreeForTonightResult {
        calls += 1; return .usable(snapshot)
    }

    func refresh() -> ThreeForTonightResult {
        calls += 1; return .usable(snapshot)
    }

    func repairAfterEligibilityChange(_: DecisionEligibilityChange) -> ThreeForTonightResult {
        calls +=
            1; return .usable(snapshot)
    }

    func reconcileAfterViewerStateChange(_: DecisionViewerStateChange) -> ThreeForTonightResult {
        calls +=
            1; return .usable(snapshot)
    }
}
