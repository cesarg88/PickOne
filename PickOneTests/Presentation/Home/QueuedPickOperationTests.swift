import Foundation
@testable import PickOne
import Testing

@MainActor
struct QueuedPickOperationTests {
    @Test func cancellationClearedBySuspendedRefreshNeverRuns() async throws {
        let harness = try await ConfirmationHarness.make()
        let base = LocalViewingDecisionRepository(store: harness.decisionFiles)
        let repository = SuspendedPickSnapshotRepository(base: base)
        let model = HomePickViewModel(
            manage: ManageViewingDecision(repository: repository), clock: { harness.now }
        )
        try await model.refreshDecision()
        #expect(model.activeDecision?.id == harness.decisionID)
        _ = try await base.apply(.init(action: .confirmation(.notWatched(harness.decisionID)), moment: harness.now))
        let bytes = try harness.decisionFiles.readActive()
        let writes = harness.decisionFiles.writeAttempts
        await repository.suspendNextSnapshot()
        let refresh = Task { try await model.refreshDecision() }
        await repository.waitForSuspendedSnapshot()
        model.cancel()
        #expect(model.savingMovieIDs == [1])
        await repository.resumeSnapshot()
        try await refresh.value
        await model.waitForPendingOperations()
        #expect(model.activeDecision == nil)
        #expect(model.savingMovieIDs.isEmpty)
        #expect(model.failedMovieIDs.isEmpty)
        #expect(!model.isShowingPickFeedback)
        model.retry(movieID: 1)
        await model.waitForPendingOperations()
        #expect(await repository.appliedActions.isEmpty)
        #expect(harness.decisionFiles.writeAttempts == writes)
        #expect(try harness.decisionFiles.readActive() == bytes)
    }

    @Test(arguments: [false, true])
    func clearedCancellationCannotAlterNewerPickForSameMovie(failsNewPick: Bool) async throws {
        let harness = try await ConfirmationHarness.make()
        let base = LocalViewingDecisionRepository(store: harness.decisionFiles)
        let repository = SuspendedPickSnapshotRepository(base: base)
        let model = HomePickViewModel(
            manage: ManageViewingDecision(repository: repository), clock: { harness.now }
        )
        try await model.refreshDecision()
        let recommendation = try #require(model.activeDecision?.recommendation)
        try model.updateSurface(ViewingDecisionSurface(recommendations: [recommendation]))
        _ = try await base.apply(.init(action: .confirmation(.notWatched(harness.decisionID)), moment: harness.now))
        await repository.suspendNextSnapshot()
        let refresh = Task { try await model.refreshDecision() }
        await repository.waitForSuspendedSnapshot()
        // This queued lifecycle snapshot holds the queue after refresh invalidates Cancel.
        model.setActive(true)
        model.cancel()
        await repository.suspendNextSnapshot()
        await repository.resumeSnapshot()
        try await refresh.value
        await repository.waitForSuspendedSnapshot()
        #expect(model.savingMovieIDs.isEmpty)
        await repository.setPickFailure(failsNewPick)
        model.pick(movieID: 1)
        #expect(model.savingMovieIDs == [1])
        await repository.resumeSnapshot()
        await model.waitForPendingOperations()
        #expect(model.savingMovieIDs.isEmpty)
        if failsNewPick {
            #expect(model.failedMovieIDs == [1])
            await repository.setPickFailure(false)
            model.retry(movieID: 1)
            await model.waitForPendingOperations()
        }
        #expect(model.failedMovieIDs.isEmpty)
        #expect(model.activeDecision?.recommendation.movieID == 1)
        #expect(model.activeDecision?.id != harness.decisionID)
        let actions = await repository.appliedActions
        #expect(!actions.contains { if case .cancel = $0 { true } else { false } })
        let persisted = try await LocalViewingDecisionRepository(store: harness.decisionFiles).snapshot()
        #expect(persisted.activeDecision?.id == model.activeDecision?.id)
        #expect(persisted.decisions.count == 2)
    }
}

private actor SuspendedPickSnapshotRepository: ViewingDecisionRepository {
    let base: LocalViewingDecisionRepository
    private var shouldSuspend = false
    private var suspended = false
    private var gate: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    private var failsPick = false
    private(set) var appliedActions: [ViewingDecisionAction] = []

    init(base: LocalViewingDecisionRepository) {
        self.base = base
    }

    func snapshot() async throws -> ViewingDecisionState {
        let snapshot = try await base.snapshot()
        if shouldSuspend {
            shouldSuspend = false
            suspended = true
            observer?.resume()
            observer = nil
            await withCheckedContinuation { gate = $0 }
        }
        return snapshot
    }

    func apply(_ operation: ViewingDecisionOperation) async throws -> ViewingDecisionReceipt {
        appliedActions.append(operation.action)
        if case .pick = operation.action, failsPick { throw ViewingDecisionError.unavailable }
        return try await base.apply(operation)
    }

    func suspendNextSnapshot() {
        shouldSuspend = true
    }

    func setPickFailure(_ value: Bool) {
        failsPick = value
    }

    func waitForSuspendedSnapshot() async {
        if suspended { return }
        await withCheckedContinuation { observer = $0 }
    }

    func resumeSnapshot() {
        suspended = false
        gate?.resume()
        gate = nil
    }
}
