import Foundation
@testable import PickOne
import Testing

struct ConfirmationSemanticRecoveryTests {
    @Test(arguments: [false, true], [false, true])
    func completedSatisfactionRequiresMatchingSnapshot(missing: Bool, hasPrevious: Bool) async throws {
        let valid = try await satisfiedEnvelope()
        var invalid = valid
        invalid.state.decisions[0].satisfaction = missing ? nil : .didNotLikeIt
        try await assertRecovery(invalid: invalid, previous: hasPrevious ? valid : nil)
    }

    @Test(arguments: [ViewingDecision.Status.cancelled, .notWatched], [
        ViewingConfirmationOperation.Stage.prepared, .applyingViewerMovieState, .viewerMovieStateCommitted,
    ])
    func incompleteConfirmationRejectsImpossibleTerminalOutcome(
        status: ViewingDecision.Status, stage: ViewingConfirmationOperation.Stage
    ) async throws {
        let valid = try await satisfiedEnvelope()
        var invalid = valid
        invalid.state.confirmationOperations = try [#require(valid.state.confirmationOperations.first)]
        invalid.state.confirmationOperations[0].stage = stage
        invalid.state.decisions[0].status = status
        invalid.state.decisions[0].confirmedAt = nil
        invalid.state.decisions[0].satisfaction = nil
        try await assertRecovery(invalid: invalid, previous: valid)
        try await assertRecovery(invalid: invalid, previous: nil)
    }

    @Test(arguments: [
        ViewingConfirmationOperation.Stage.prepared,
        .applyingViewerMovieState,
        .viewerMovieStateCommitted,
    ])
    func supersededPendingConfirmationRemainsRecoverable(stage: ViewingConfirmationOperation.Stage) async throws {
        let harness = try await ConfirmationHarness.make()
        let repository = LocalViewingDecisionRepository(store: harness.decisionFiles)
        let operation = ViewingConfirmationOperation(
            id: UUID(), decisionID: harness.decisionID, movieID: 1,
            createdAt: harness.now.wall, reaction: nil
        )
        _ = try await repository.apply(.init(action: .confirmation(.prepare(operation)), moment: harness.now))
        for next in [ViewingConfirmationOperation.Stage.applyingViewerMovieState, .viewerMovieStateCommitted] {
            if try await repository.snapshot().confirmationOperations.first?.stage == stage { break }
            _ = try await repository.apply(.init(
                action: .confirmation(.advance(operation.id, next)),
                moment: harness.now
            ))
        }
        let surface = try ViewingDecisionTestFixtures.surface()
        let recommendation = try #require(surface.recommendations.last)
        _ = try await repository.apply(.init(
            action: .pick(recommendation, snapshot: surface, isVisible: false), moment: harness.now
        ))
        let recovered = try await LocalViewingDecisionRepository(store: harness.decisionFiles).snapshot()
        #expect(recovered.decisions.first?.status == .superseded)
        #expect(recovered.confirmationOperations.first?.stage == stage)
        #expect(harness.decisionFiles.base.quarantined.isEmpty)
    }

    private func satisfiedEnvelope() async throws -> ViewingDecisionEnvelope {
        let harness = try await ConfirmationHarness.make()
        let coordinator = harness.coordinator()
        try await coordinator.confirm(harness.decisionID, operationID: UUID())
        try await coordinator.confirm(harness.decisionID, operationID: UUID(), reaction: .loveIt)
        return try ViewingDecisionEnvelope.decode(#require(try harness.decisionFiles.readActive()))
    }

    private func assertRecovery(invalid: ViewingDecisionEnvelope, previous: ViewingDecisionEnvelope?) async throws {
        let bytes = try invalid.encoded()
        #expect(throws: ViewingDecisionError.invalidData) { try ViewingDecisionEnvelope.decode(bytes) }
        let store = MemoryViewingDecisionStore()
        try store.replaceActive(bytes)
        let previousBytes = try previous?.encoded()
        if let previousBytes { try store.replacePrevious(previousBytes) }
        let repository = LocalViewingDecisionRepository(store: store)
        if let previous {
            #expect(try await repository.snapshot() == previous.state)
            #expect(try store.readActive() == previousBytes)
            #expect(try await LocalViewingDecisionRepository(store: store).snapshot() == previous.state)
        } else {
            await #expect(throws: ViewingDecisionError.unavailable) { try await repository.snapshot() }
            #expect(try store.readActive() == bytes)
        }
        #expect(store.quarantined == [bytes])
    }
}
