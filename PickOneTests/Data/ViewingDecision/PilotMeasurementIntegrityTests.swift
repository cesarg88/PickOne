import Foundation
@testable import PickOne
import Testing

struct PilotMeasurementIntegrityTests {
    @Test(arguments: [false, true], [false, true])
    func missingCurrentJournalQuarantinesAndRecoversPendingWork(hasPrevious: Bool, explicitNull: Bool) async throws {
        let store = MemoryViewingDecisionStore()
        var envelope = try decisionEnvelope()
        let decision = try #require(envelope.state.decisions.first)
        envelope.state.confirmationOperations = [.init(
            id: UUID(), decisionID: decision.id, movieID: decision.recommendation.movieID,
            createdAt: ViewingDecisionTestFixtures.moment(50000).wall, reaction: nil, stage: .prepared
        )]
        let valid = try envelope.encoded()
        var json = try object(valid)
        if explicitNull {
            json["confirmationOperations"] = NSNull()
        } else {
            json.removeValue(forKey: "confirmationOperations")
        }
        let invalid = try JSONSerialization.data(withJSONObject: json)
        store.active = invalid
        store.previous = hasPrevious ? valid : nil
        let repository = LocalViewingDecisionRepository(store: store)
        if hasPrevious {
            #expect(try await repository.snapshot().confirmationOperations == envelope.state.confirmationOperations)
            #expect(store.active == valid)
        } else {
            await #expect(throws: ViewingDecisionError.unavailable) { try await repository.snapshot() }
            #expect(store.active == invalid)
        }
        #expect(store.quarantined == [invalid])
    }

    @Test(arguments: [1, 2])
    func legacyMissingJournalMigratesToExplicitEmptyArray(schema: Int) async throws {
        let store = MemoryViewingDecisionStore()
        var json = try object(decisionEnvelope().encoded())
        json["schemaVersion"] = schema
        json.removeValue(forKey: "confirmationOperations")
        store.active = try JSONSerialization.data(withJSONObject: json)
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.expire, 1810))
        let written = try object(#require(store.active))
        #expect(written["schemaVersion"] as? Int == 3)
        #expect((written["confirmationOperations"] as? [Any])?.isEmpty == true)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().activeDecision != nil)
        #expect(store.quarantined.isEmpty)
    }

    @Test func legacyPendingJournalSurvivesMigrationAndRelaunch() async throws {
        let store = MemoryViewingDecisionStore()
        var envelope = try decisionEnvelope()
        let decision = try #require(envelope.state.decisions.first)
        envelope.state.confirmationOperations = [.init(
            id: UUID(), decisionID: decision.id, movieID: decision.recommendation.movieID,
            createdAt: ViewingDecisionTestFixtures.moment(50000).wall, reaction: nil, stage: .prepared
        )]
        var json = try object(envelope.encoded())
        json["schemaVersion"] = 2
        store.active = try JSONSerialization.data(withJSONObject: json)
        _ = try await LocalViewingDecisionRepository(store: store).apply(operation(.expire, 50001))
        #expect(try object(#require(store.active))["schemaVersion"] as? Int == 3)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().confirmationOperations
            == envelope.state.confirmationOperations)
        #expect(store.quarantined.isEmpty)
    }

    @Test func legacyNotWatchedReceiptSurvivesSummaryMigrationRelaunchAndRetry() async throws {
        let store = MemoryViewingDecisionStore()
        store.active = try decisionEnvelope().encoded()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.expire, 1810))
        let id = try #require(try await repository.snapshot().activeDecision?.id)
        let answer = operation(.confirmation(.notWatched(id)), 2000)
        _ = try await repository.apply(answer)
        var json = try object(#require(store.active))
        json["schemaVersion"] = 2
        var receipts = try #require(json["receipts"] as? [[String: Any]])
        for index in receipts.indices {
            receipts[index].removeValue(forKey: "recordedAt")
        }
        json["receipts"] = receipts
        store.active = try JSONSerialization.data(withJSONObject: json)
        let upgraded = LocalViewingDecisionRepository(store: store)
        #expect(try await upgraded.measurementSummary(at: ViewingDecisionTestFixtures.moment(2001).wall)
            .notWatched == 1)
        _ = try await upgraded.apply(operation(.expire, 2002))
        #expect(try object(#require(store.active))["schemaVersion"] as? Int == 3)
        let beforeRetry = store.active
        let reopened = LocalViewingDecisionRepository(store: store)
        let receipt = try await reopened.apply(answer)
        #expect(receipt.operationID == answer.id)
        #expect(receipt.sessionID == nil && receipt.decisionID == nil)
        #expect(store.active == beforeRetry)
        let export = try await object(reopened.exportMeasurement(at: ViewingDecisionTestFixtures.moment(2003).wall))
        let records = try #require(export["records"] as? [String: Any])
        let exportedReceipts = try #require(records["receipts"] as? [[String: Any]])
        #expect(exportedReceipts.contains { $0["operationID"] as? String == answer.id.uuidString })
        _ = try await reopened.measurementSummary(at: ViewingDecisionTestFixtures.moment(2000 + 180 * 86400).wall)
        #expect(try !ViewingDecisionEnvelope.decode(#require(store.active)).receipts
            .contains { $0.operationID == answer.id })
        #expect(store.active == store.previous)
    }

    @Test(arguments: ["refreshCount", "postponementCount"], [false, true])
    func overflowingPersistedCountersRecoverOrRemainUnavailable(field: String, hasPrevious: Bool) async throws {
        let store = MemoryViewingDecisionStore()
        var envelope = try decisionEnvelope()
        let surface = try ViewingDecisionTestFixtures.surface()
        try envelope.state.apply(.expire, at: ViewingDecisionTestFixtures.moment(1810))
        try envelope.state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(2000))
        try envelope.state.apply(
            .pick(#require(surface.recommendations.first), snapshot: surface, isVisible: true),
            at: ViewingDecisionTestFixtures.moment(2010)
        )
        let valid = try envelope.encoded()
        var json = try object(valid)
        let key = field == "refreshCount" ? "sessions" : "decisions"
        var rows = try #require(json[key] as? [[String: Any]])
        for index in rows.indices {
            rows[index][field] = Int.max - 1
            if field == "postponementCount" {
                rows[index]["nextConfirmationAt"] = ViewingDecisionTestFixtures.moment(100_000).wall
                    .timeIntervalSince1970 * 1000
            }
        }
        json[key] = rows
        let invalid = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: ViewingDecisionError.invalidData) { try ViewingDecisionEnvelope.decode(invalid) }
        // Prove rejection first: never deliberately execute a known trapping projection in the red test.
        guard (try? ViewingDecisionEnvelope.decode(invalid)) == nil else { return }
        store.active = invalid
        store.previous = hasPrevious ? valid : nil
        let repository = LocalViewingDecisionRepository(store: store)
        let now = ViewingDecisionTestFixtures.moment(2020).wall
        if hasPrevious {
            #expect(try await repository.measurementSummary(at: now).refreshes == 0)
            #expect(try await repository.measurementSummary(at: now).postponements == 0)
            _ = try await repository.exportMeasurement(at: now)
            #expect(store.active == valid)
            #expect(store.quarantined == [invalid])
        } else {
            await #expect(throws: ViewingDecisionError.unavailable) { try await repository.measurementSummary(at: now) }
            await #expect(throws: ViewingDecisionError.unavailable) { try await repository.exportMeasurement(at: now) }
            #expect(store.active == invalid)
            #expect(store.quarantined.allSatisfy { $0 == invalid })
            #expect(!store.quarantined.isEmpty)
        }
    }

    private func decisionEnvelope() throws -> ViewingDecisionEnvelope {
        var envelope = ViewingDecisionEnvelope()
        let surface = try ViewingDecisionTestFixtures.surface()
        try envelope.state.apply(.activate(surface), at: ViewingDecisionTestFixtures.moment(0))
        try envelope.state.apply(
            .pick(#require(surface.recommendations.first), snapshot: surface, isVisible: true),
            at: ViewingDecisionTestFixtures.moment(10)
        )
        return envelope
    }

    private func object(_ bytes: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }

    private func operation(_ action: ViewingDecisionAction, _ seconds: Double) -> ViewingDecisionOperation {
        ViewingDecisionOperation(action: action, moment: ViewingDecisionTestFixtures.moment(seconds))
    }
}
