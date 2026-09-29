import Foundation
@testable import PickOne
import Testing

struct PilotMeasurementLifecycleTests {
    @Test func oldPendingSessionCanStillCompleteAndCaptureOptionalSatisfaction() async throws {
        let store = MemoryViewingDecisionStore()
        let decisions = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        _ = try await decisions.apply(.init(action: .activate(surface), moment: ViewingDecisionTestFixtures.moment(0)))
        _ = try await decisions.apply(.init(
            action: .pick(selection, snapshot: surface, isVisible: true), moment: ViewingDecisionTestFixtures.moment(10)
        ))
        _ = try await decisions.apply(.init(action: .expire, moment: ViewingDecisionTestFixtures.moment(1810)))
        let decisionID = try #require(try await decisions.snapshot().activeDecision?.id)
        let future = ViewingDecisionTestFixtures.moment(200 * 86400)
        #expect(try await decisions.measurementSummary(at: future.wall).sessions == 1)
        try await decisions.deleteMeasurement(operationID: UUID(), at: future.wall)
        #expect(try await decisions.snapshot().sessions.count == 1)
        let viewerFiles = InMemoryLocalViewerStateFileStore()
        let viewer = LocalViewerStateRepository(fileStore: viewerFiles, legacySource: InMemoryLegacyViewerStateSource())
        let coordinator = ConfirmViewingDecision(
            decisions: decisions, viewerState: viewer,
            metadata: { _ in try MovieFeedbackMetadata(title: "Movie", releaseYear: 2020, posterPath: nil) },
            moment: { future }
        )
        try await coordinator.confirm(decisionID, operationID: UUID())
        #expect(try await decisions.measurementSummary(at: future.wall).confirmedWatched == 1)
        try await coordinator.confirm(decisionID, operationID: UUID(), reaction: .loveIt)
        let reopened = LocalViewingDecisionRepository(store: store)
        #expect(try await reopened.snapshot().decisions.first?.satisfaction == .loveIt)
        #expect(try await viewer.state(movieID: selection.movieID)?.pickOneProvenance != nil)
    }

    @Test func boundedSearchEvictsItsIdempotencyReceiptTogether() async throws {
        var envelope = ViewingDecisionEnvelope()
        let date = ViewingDecisionTestFixtures.moment(0).wall
        for _ in 0 ..< 1000 {
            let id = UUID()
            envelope.state.searchEvidence.append(PilotSearchEvidence(
                id: id, recordedAt: date, duration: 1, stage: .normal, outcome: .usable
            ))
            envelope.receipts.append(.init(operationID: id, sessionID: nil, decisionID: nil))
        }
        let firstID = try #require(envelope.state.searchEvidence.first?.id)
        let store = MemoryViewingDecisionStore()
        store.active = try envelope.encoded()
        let newID = UUID()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(.init(
            id: newID,
            action: .search(PilotSearchEvidence(
                id: newID, recordedAt: date, duration: 2, stage: .finalExpansion, outcome: .exhausted
            )), moment: ViewingDecisionTestFixtures.moment(1)
        ))
        let bytes = try #require(store.active)
        let result = try ViewingDecisionEnvelope.decode(bytes)
        #expect(result.state.searchEvidence.count == 1000)
        #expect(result.receipts.count == 1000)
        #expect(!result.receipts.contains { $0.operationID == firstID })
        #expect(result.state.searchEvidence.last?.id == newID)
    }

    @Test func anOlderDeletionRetryCannotDeleteNewHistory() async throws {
        let repository = LocalViewingDecisionRepository(store: MemoryViewingDecisionStore())
        let firstID = UUID()
        try await repository.deleteMeasurement(operationID: firstID, at: Date())
        try await repository.deleteMeasurement(operationID: UUID(), at: Date())
        _ = try await repository.apply(.init(
            action: .activate(ViewingDecisionTestFixtures.surface()), moment: ViewingDecisionTestFixtures.moment(0)
        ))
        _ = try await repository.apply(.init(action: .expire, moment: ViewingDecisionTestFixtures.moment(1800)))
        try await repository.deleteMeasurement(operationID: firstID, at: Date())
        #expect(try await repository.snapshot().sessions.count == 1)
    }

    @Test func concurrentDeletionRetriesLeaveOneValidGeneration() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        _ = try await repository.apply(.init(action: .activate(surface), moment: ViewingDecisionTestFixtures.moment(0)))
        _ = try await repository.apply(.init(action: .expire, moment: ViewingDecisionTestFixtures.moment(1800)))
        let deletionID = UUID()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    try await repository.deleteMeasurement(
                        operationID: deletionID,
                        at: ViewingDecisionTestFixtures.moment(2000).wall
                    )
                }
            }
            try await group.waitForAll()
        }
        let reopened = LocalViewingDecisionRepository(store: store)
        #expect(try await reopened.snapshot().sessions.isEmpty)
        let bytes = try #require(store.active)
        #expect(try ViewingDecisionEnvelope.decode(bytes).deletionOperationIDs == [deletionID])
    }
}
