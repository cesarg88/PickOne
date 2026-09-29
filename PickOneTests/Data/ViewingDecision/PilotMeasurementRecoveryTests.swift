import Foundation
@testable import PickOne
import Testing

struct PilotMeasurementRecoveryTests {
    @Test(arguments: [1, 2])
    func legacyObservationMigratesToExplicitNullAndSurvivesRelaunch(schema: Int) async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        var json = try object(#require(store.active))
        json["schemaVersion"] = schema
        var sessions = try #require(json["sessions"] as? [[String: Any]])
        sessions[0].removeValue(forKey: "observedMovieIDs")
        sessions[0].removeValue(forKey: "alreadyWatchedMovieIDs")
        json["sessions"] = sessions
        store.active = try JSONSerialization.data(withJSONObject: json)
        let migrated = LocalViewingDecisionRepository(store: store)
        _ = try await migrated.apply(operation(.expire, 1800))
        let written = try object(#require(store.active))
        let writtenSessions = try #require(written["sessions"] as? [[String: Any]])
        #expect(writtenSessions[0]["observedMovieIDs"] is NSNull)
        let reopened = LocalViewingDecisionRepository(store: store)
        let summary = try await reopened.measurementSummary(at: ViewingDecisionTestFixtures.moment(1801).wall)
        #expect(summary.sessions == 1)
        #expect(summary.sessionsWithObservationEvidence == 0)
        #expect(summary.alreadyWatchedRate == nil)
        #expect(store.quarantined.isEmpty)
    }

    @Test(arguments: ["missing", "wrongType"], [false, true])
    func malformedObservationQuarantinesExactBytes(kind: String, hasPrevious: Bool) async throws {
        let store = MemoryViewingDecisionStore()
        _ = try await LocalViewingDecisionRepository(store: store)
            .apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        let valid = try #require(store.active)
        var json = try object(valid)
        var sessions = try #require(json["sessions"] as? [[String: Any]])
        if kind == "missing" {
            sessions[0].removeValue(forKey: "observedMovieIDs")
        } else {
            sessions[0]["observedMovieIDs"] = "invalid"
        }
        json["sessions"] = sessions
        let malformed = try JSONSerialization.data(withJSONObject: json)
        store.active = malformed
        store.previous = hasPrevious ? valid : nil
        let reopened = LocalViewingDecisionRepository(store: store)
        if hasPrevious {
            #expect(try await reopened.snapshot().sessions.first?.observedMovieIDs == [1, 2])
            #expect(store.active == valid)
        } else {
            await #expect(throws: ViewingDecisionError.unavailable) { try await reopened.snapshot() }
            #expect(store.active == malformed)
        }
        #expect(store.quarantined == [malformed])
    }

    @Test(arguments: [false, true])
    func receiptOnlyRetentionPersistsAndCannotRecoverExpiredReceipts(useMutation: Bool) async throws {
        let store = MemoryViewingDecisionStore()
        let oldID = UUID(), recentID = UUID(), legacyID = UUID()
        var json = try object(ViewingDecisionEnvelope().encoded())
        let start = ViewingDecisionTestFixtures.moment(0).wall
        json["receipts"] = [
            ["operationID": oldID.uuidString, "recordedAt": start.timeIntervalSince1970 * 1000],
            [
                "operationID": recentID.uuidString,
                "recordedAt": start.addingTimeInterval(1).timeIntervalSince1970 * 1000,
            ],
            ["operationID": legacyID.uuidString],
        ]
        store.active = try JSONSerialization.data(withJSONObject: json)
        store.previous = store.active
        let repository = LocalViewingDecisionRepository(store: store)
        let boundary = ViewingDecisionTestFixtures.moment(180 * 86400)
        let before = store.active
        let exported = try await object(repository.exportMeasurement(at: boundary.wall))
        let records = try #require(exported["records"] as? [String: Any])
        let receipts = try #require(records["receipts"] as? [[String: Any]])
        #expect(receipts.compactMap { $0["operationID"] as? String } == [recentID.uuidString])
        #expect(store.active == before)
        #expect(store.previous == before)
        if useMutation {
            _ = try await repository.apply(operation(.expire, 180 * 86400))
        } else {
            _ = try await repository.measurementSummary(at: boundary.wall)
        }
        #expect(store.active != before)
        #expect(store.active == store.previous)
        store.active = Data("broken after pruning".utf8)
        let recovered = LocalViewingDecisionRepository(store: store)
        _ = try await recovered.snapshot()
        let envelope = try ViewingDecisionEnvelope.decode(#require(store.active))
        #expect(!envelope.receipts.contains { $0.operationID == oldID || $0.operationID == legacyID })
        #expect(envelope.receipts.contains { $0.operationID == recentID })
        let recoveredExport = try await object(recovered.exportMeasurement(at: boundary.wall))
        let recoveredRecords = try #require(recoveredExport["records"] as? [String: Any])
        let recoveredReceipts = try #require(recoveredRecords["receipts"] as? [[String: Any]])
        #expect(!recoveredReceipts.contains { $0["operationID"] as? String == oldID.uuidString })
    }

    @Test func terminalReceiptExpiresAtBoundaryAcrossRelaunch() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        _ = try await repository.apply(operation(.activate(ViewingDecisionTestFixtures.surface()), 0))
        let expiration = operation(.expire, 1800)
        _ = try await repository.apply(expiration)
        let boundary = ViewingDecisionTestFixtures.moment(1800 + 180 * 86400).wall
        let reopened = LocalViewingDecisionRepository(store: store)
        _ = try await reopened.measurementSummary(at: boundary.addingTimeInterval(-1))
        #expect(try ViewingDecisionEnvelope.decode(#require(store.active)).receipts.contains {
            $0.operationID == expiration.id
        })
        _ = try await reopened.measurementSummary(at: boundary)
        #expect(try ViewingDecisionEnvelope.decode(#require(store.active)).receipts.isEmpty)
        #expect(store.previous == store.active)
    }

    @Test(arguments: ["active", "previous"])
    func failedReceiptOnlyPruningPreservesActiveAndRetriesAfterRelaunch(boundary: String) async throws {
        let store = MemoryViewingDecisionStore()
        var envelope = ViewingDecisionEnvelope()
        envelope.receipts = [.init(
            operationID: UUID(), sessionID: nil, decisionID: nil,
            recordedAt: ViewingDecisionTestFixtures.moment(0).wall
        )]
        let before = try envelope.encoded()
        store.active = before
        store.previous = before
        store.failure = boundary
        let date = ViewingDecisionTestFixtures.moment(180 * 86400).wall
        await #expect(throws: ViewingDecisionError.unavailable) {
            try await LocalViewingDecisionRepository(store: store).measurementSummary(at: date)
        }
        #expect(store.active == before)
        store.failure = nil
        _ = try await LocalViewingDecisionRepository(store: store).measurementSummary(at: date)
        #expect(try ViewingDecisionEnvelope.decode(#require(store.active)).receipts.isEmpty)
        #expect(store.active == store.previous)
    }

    @Test func retentionKeepsReceiptsForOpenWorkAndRetainedSearches() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let activation = try operation(.activate(ViewingDecisionTestFixtures.surface()), 0)
        _ = try await repository.apply(activation)
        var envelope = try ViewingDecisionEnvelope.decode(#require(store.active))
        let searchID = UUID()
        let boundary = ViewingDecisionTestFixtures.moment(180 * 86400).wall
        envelope.state.searchEvidence = [.init(
            id: searchID, recordedAt: boundary, duration: 1, stage: .normal, outcome: .usable
        )]
        envelope.receipts.append(.init(operationID: searchID, sessionID: nil, decisionID: nil))
        store.active = try envelope.encoded()
        _ = try await LocalViewingDecisionRepository(store: store).measurementSummary(at: boundary)
        let retained = try ViewingDecisionEnvelope.decode(#require(store.active))
        #expect(Set(retained.receipts.map(\.operationID)) == [activation.id, searchID])
        #expect(retained.state.sessions.count == 1)
        #expect(retained.state.searchEvidence.count == 1)
    }

    private func object(_ bytes: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }

    private func operation(_ action: ViewingDecisionAction, _ seconds: Double) -> ViewingDecisionOperation {
        ViewingDecisionOperation(action: action, moment: ViewingDecisionTestFixtures.moment(seconds))
    }
}
