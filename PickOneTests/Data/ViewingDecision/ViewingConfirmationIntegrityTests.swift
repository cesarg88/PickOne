import Foundation
@testable import PickOne
import Testing

struct ViewingConfirmationIntegrityTests {
    @Test(arguments: MovieReaction.allCases)
    func everySatisfactionOutcomeIsAnImmutableSnapshot(reaction: MovieReaction) async throws {
        let harness = try await ConfirmationHarness.make()
        _ = try await harness.viewerRepository().apply(
            .init(movieID: 1, action: .saveToWatchlist), metadata: harness.metadata
        )
        try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        let operationID = UUID()
        try await harness.coordinator().confirm(harness.decisionID, operationID: operationID, reaction: reaction)
        let before = try await harness.viewerRepository().snapshot()
        try await harness.coordinator().confirm(harness.decisionID, operationID: operationID, reaction: reaction)
        #expect(try await harness.viewerRepository().snapshot() == before)
        #expect(before.states.first?.reaction == reaction)
        #expect(before.states.first?.watchlistIntent == nil)
        #expect(before.states.first?.pickOneProvenance != nil)
        #expect(try await harness.coordinator().snapshot().decisions.first?.satisfaction == reaction)
    }

    @Test func simultaneousRetriesCommitOnlyOneOperation() async throws {
        let harness = try await ConfirmationHarness.make()
        let coordinator = harness.coordinator()
        let operationID = UUID()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { try await coordinator.confirm(harness.decisionID, operationID: operationID) }
            }
            try await group.waitForAll()
        }
        let state = try await coordinator.snapshot()
        #expect(state.confirmationOperations.count == 1)
        #expect(state.confirmationOperations.first?.stage == .completed)
        #expect(state.decisions.first?.status == .confirmedWatched)
    }

    @Test func notWatchedAndPostponementNeverWriteViewerState() async throws {
        let harness = try await ConfirmationHarness.make()
        let coordinator = harness.coordinator()
        let id = UUID()
        try await coordinator.answer(.notYet(harness.decisionID), operationID: id)
        try await coordinator.answer(.notYet(harness.decisionID), operationID: id)
        #expect(try await coordinator.snapshot().activeDecision?.postponementCount == 1)
        try await coordinator.answer(.notWatched(harness.decisionID), operationID: UUID())
        #expect(try await coordinator.snapshot().decisions.first?.status == .notWatched)
        #expect(harness.viewerFiles.activeData == nil)
        #expect(harness.viewerFiles.previousData == nil)
    }

    @Test func cancelledTaskPreparesNothing() async throws {
        let harness = try await ConfirmationHarness.make()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await harness.coordinator().snapshot().confirmationOperations.isEmpty == true)
        #expect(harness.viewerFiles.activeData == nil)
    }

    @Test func corruptMeasurementCannotCreateOrRemoveProvenance() async throws {
        let harness = try await ConfirmationHarness.make()
        try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        let before = try await harness.viewerRepository().snapshot()
        let corrupt = Data("corrupt measurement".utf8)
        harness.decisionFiles.base.active = corrupt
        harness.decisionFiles.base.previous = corrupt
        await #expect(throws: ViewingDecisionError.unavailable) { try await harness.coordinator().reconcile() }
        #expect(try await harness.viewerRepository().snapshot() == before)
        #expect(harness.decisionFiles.base.quarantined == [corrupt, corrupt])
        #expect(harness.decisionFiles.base.active == corrupt)
    }

    @Test func committedOperationRecoversOfflineAfterUnwatched() async throws {
        let harness = try await ConfirmationHarness.make()
        harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + 6
        await #expect(throws: (any Error).self) {
            try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        }
        _ = try await harness.viewerRepository().apply(
            .init(movieID: 1, action: .markUnwatched),
            metadata: harness.metadata
        )
        harness.decisionFiles.failAtWrite = nil
        let coordinator = ConfirmViewingDecision(
            decisions: LocalViewingDecisionRepository(store: harness.decisionFiles),
            viewerState: harness.viewerRepository(),
            metadata: { _ in throw ViewingDecisionError.unavailable }, moment: { harness.now }
        )
        try await coordinator.reconcile()
        #expect(try await harness.viewerRepository().state(movieID: 1) == nil)
        #expect(try await coordinator.snapshot().decisions.first?.status == .confirmedWatched)
    }

    @Test func v1PickRemainsPendingAfterUpgrade() async throws {
        let harness = try await ConfirmationHarness.make()
        let original = try #require(harness.decisionFiles.base.active)
        var json = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
        json["schemaVersion"] = 1
        json.removeValue(forKey: "confirmationOperations")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        harness.decisionFiles.base.active = legacy
        let snapshot = try await harness.coordinator().snapshot()
        #expect(snapshot.activeDecision?.id == harness.decisionID)
        #expect(snapshot.confirmationOperations.isEmpty)
        #expect(snapshot.activeDecision?.postponementCount == 0)
        try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        #expect(try await harness.coordinator().snapshot().decisions.first?.status == .confirmedWatched)
    }
}
