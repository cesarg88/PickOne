import Foundation
@testable import PickOne
import Testing

struct PilotMeasurementPersistenceTests {
    @Test func exactRetentionBoundaryAndRecoveryDoNotResurrectHistory() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        _ = try await repository.apply(operation(.activate(surface), 0))
        _ = try await repository.apply(operation(.expire, 1800))
        let boundary = ViewingDecisionTestFixtures.moment(1800 + 180 * 86400).wall
        #expect(try await repository.measurementSummary(at: boundary.addingTimeInterval(-1)).sessions == 1)
        #expect(try await repository.measurementSummary(at: boundary).sessions == 0)
        #expect(store.active == store.previous)
        store.active = Data("broken".utf8)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().sessions.isEmpty)
    }

    @Test(arguments: ["active", "previous"])
    func failedDeletionPreservesCompleteStateAndRetryIsIdempotent(boundary: String) async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        _ = try await repository.apply(operation(.expire, 1800))
        let before = store.active
        store.failure = boundary
        let id = UUID()
        await #expect(throws: ViewingDecisionError.unavailable) {
            try await repository.deleteMeasurement(operationID: id, at: ViewingDecisionTestFixtures.moment(2000).wall)
        }
        #expect(store.active == before)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().sessions.count == 1)
        store.failure = nil
        let reopened = LocalViewingDecisionRepository(store: store)
        try await reopened.deleteMeasurement(operationID: id, at: ViewingDecisionTestFixtures.moment(2000).wall)
        let deleted = store.active
        try await LocalViewingDecisionRepository(store: store).deleteMeasurement(
            operationID: id, at: ViewingDecisionTestFixtures.moment(2001).wall
        )
        #expect(store.active == deleted)
        #expect(store.previous == deleted)
        #expect(try ViewingDecisionEnvelope.decode(#require(deleted)).id !=
            ViewingDecisionEnvelope.decode(#require(before)).id)
    }

    @Test func deletionAndRetentionPreservePendingAndIncompleteConfirmationThenProvenance() async throws {
        let harness = try await ConfirmationHarness.make()
        let repository = LocalViewingDecisionRepository(store: harness.decisionFiles)
        let farFuture = harness.now.wall.addingTimeInterval(400 * 86400)
        for offset in [0.0, 86400, 172_800] {
            _ = try await repository.apply(ViewingDecisionOperation(
                action: .confirmation(.notYet(harness.decisionID)),
                moment: DecisionMoment(
                    wall: harness.now.wall.addingTimeInterval(offset), monotonicSeconds: offset,
                    runtimeID: UUID()
                )
            ))
        }
        try await repository.deleteMeasurement(operationID: UUID(), at: farFuture)
        #expect(try await repository.measurementSummary(at: farFuture).pending == 1)
        #expect(try await repository.snapshot().manualConfirmations.count == 1)
        harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + 6
        await #expect(throws: (any Error).self) {
            try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        }
        harness.decisionFiles.failAtWrite = nil
        let interrupted = LocalViewingDecisionRepository(store: harness.decisionFiles)
        try await interrupted.deleteMeasurement(operationID: UUID(), at: farFuture)
        #expect(try await interrupted.snapshot().confirmationOperations.count == 1)
        try await harness.coordinator().reconcile()
        let viewerBefore = harness.viewerFiles.activeData
        let completed = LocalViewingDecisionRepository(store: harness.decisionFiles)
        try await completed.deleteMeasurement(operationID: UUID(), at: farFuture)
        #expect(try await LocalViewingDecisionRepository(store: harness.decisionFiles).snapshot().decisions.isEmpty)
        #expect(try await harness.viewerRepository().state(movieID: 1)?.pickOneProvenance != nil)
        #expect(harness.viewerFiles.activeData == viewerBefore)
    }

    @Test func exportIsReadOnlyAndContainsAllowlistedRecordsAndDerivedSummary() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        let before = store.active
        let previous = store.previous
        let data = try await repository.exportMeasurement(at: ViewingDecisionTestFixtures.moment(1).wall)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["schemaVersion", "exportedAt", "summary", "records"])
        let summary = try #require(json["summary"] as? [String: Any])
        #expect(summary["observedMovies"] as? Int == 2)
        let text = try #require(String(data: data, encoding: .utf8))
        for forbidden in ["title", "poster", "provider", "query", "prompt", "token", "device"] {
            #expect(!text.localizedCaseInsensitiveContains(forbidden))
        }
        #expect(store.active == before)
        #expect(store.previous == previous)
    }

    @Test func oldSchemaKeepsObservationRateUnavailable() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        let bytes = try #require(store.active)
        var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        json["schemaVersion"] = 2
        var sessions = try #require(json["sessions"] as? [[String: Any]])
        sessions[0].removeValue(forKey: "observedMovieIDs")
        sessions[0].removeValue(forKey: "alreadyWatchedMovieIDs")
        json["sessions"] = sessions
        json.removeValue(forKey: "searchEvidence")
        store.active = try JSONSerialization.data(withJSONObject: json)
        let reopened = LocalViewingDecisionRepository(store: store)
        let summary = try await reopened.measurementSummary(at: ViewingDecisionTestFixtures.moment(1).wall)
        #expect(summary.sessions == 1)
        #expect(summary.sessionsWithObservationEvidence == 0)
        #expect(summary.alreadyWatchedRate == nil)
    }

    @Test(arguments: ["searchEvidence", "deletionOperationIDs"])
    func missingCurrentSchemaEvidenceIsNotInventedAsEmpty(field: String) async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        let bytes = try #require(store.active)
        var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        json.removeValue(forKey: field)
        let incomplete = try JSONSerialization.data(withJSONObject: json)
        store.active = incomplete
        await #expect(throws: ViewingDecisionError.unavailable) {
            try await LocalViewingDecisionRepository(store: store)
                .measurementSummary(at: ViewingDecisionTestFixtures.moment(1).wall)
        }
        #expect(store.quarantined == [incomplete])
        #expect(store.active == incomplete)
    }

    @Test func corruptReportAndExportAreUnavailableWithoutOverwritingBytes() async throws {
        let store = MemoryViewingDecisionStore()
        let invalid = Data("broken".utf8)
        store.active = invalid
        let repository = LocalViewingDecisionRepository(store: store)
        await #expect(throws: ViewingDecisionError.unavailable) { try await repository.measurementSummary(at: Date()) }
        await #expect(throws: ViewingDecisionError.unavailable) { try await repository.exportMeasurement(at: Date()) }
        await #expect(throws: ViewingDecisionError.unavailable) {
            try await repository.deleteMeasurement(operationID: UUID(), at: Date())
        }
        #expect(store.active == invalid)
    }

    private func operation(_ action: ViewingDecisionAction, _ seconds: Double) -> ViewingDecisionOperation {
        ViewingDecisionOperation(action: action, moment: ViewingDecisionTestFixtures.moment(seconds))
    }
}
