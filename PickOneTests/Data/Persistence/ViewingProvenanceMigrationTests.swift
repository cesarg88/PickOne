import Foundation
@testable import PickOne
import Testing

struct ViewingProvenanceMigrationTests {
    @Test func v3PreservesEveryFieldWithoutInferringProvenance() async throws {
        let base = LocalViewerStateTestFixtures.emptyEnvelope(id: UUID())
        let metadata = try MovieFeedbackMetadata(title: "Historic movie", releaseYear: 2001, posterPath: "/poster.jpg")
        let state = try ViewerMovieState(
            movieID: 1,
            displayMetadata: metadata,
            watchState: .watched,
            preference: .reaction(.loveIt),
            watchlistIntent: nil,
            stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let legacy = LocalViewerStateEnvelopeV3DTO(
            envelopeSchemaVersion: 3,
            committedStateSnapshotID: base.committedStateSnapshotID,
            recommendationSuppressionEpochID: base.recommendationSuppressionEpochID,
            viewerProfileState: base.viewerProfileState,
            viewerMovieStates: [LocalViewerStateEnvelopeMapper().map(state)],
            migrationRecord: base.migrationRecord
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let original = try encoder.encode(legacy)
        let files = InMemoryLocalViewerStateFileStore(activeData: original)
        let snapshot = try await repository(files).snapshot()
        #expect(snapshot.states.first?.pickOneProvenance == nil)
        #expect(snapshot.states.first?.reaction == .loveIt)
        #expect(snapshot.id.rawValue == base.committedStateSnapshotID)
        #expect(snapshot.recommendationSuppressionEpochID.rawValue == base.recommendationSuppressionEpochID)
        #expect(files.previousData == original)
        let decoded = try JSONLocalViewerStateEnvelopeCoder().decode(#require(files.activeData))
        guard case let .currentV4(migrated) = decoded else { Issue.record("Expected v4"); return }
        #expect(migrated.viewerProfileState == legacy.viewerProfileState)
        #expect(migrated.viewerMovieStates == legacy.viewerMovieStates)
        #expect(migrated.migrationRecord == legacy.migrationRecord)
        #expect(try await repository(files).snapshot() == snapshot)
    }

    @Test(arguments: ["active", "previous"])
    func failedMigrationKeepsExactV3Bytes(boundary: String) async throws {
        let base = LocalViewerStateTestFixtures.emptyEnvelope(id: UUID())
        var json = try #require(JSONSerialization
            .jsonObject(with: JSONLocalViewerStateEnvelopeCoder().encode(base)) as? [String: Any])
        json["envelopeSchemaVersion"] = 3
        json.removeValue(forKey: "appliedConfirmationOperations")
        let bytes = try JSONSerialization.data(withJSONObject: json)
        let files = InMemoryLocalViewerStateFileStore(activeData: bytes)
        files.rejectActiveReplacement = boundary == "active"
        files.rejectPreviousReplacement = boundary == "previous"
        await #expect(throws: (any Error).self) { _ = try await repository(files).snapshot() }
        #expect(files.activeData == bytes)
        #expect(files.quarantinedItems.isEmpty)
        files.rejectActiveReplacement = false
        files.rejectPreviousReplacement = false
        #expect(try await repository(files).snapshot().id.rawValue == base.committedStateSnapshotID)
        #expect(files.previousData == bytes)
    }

    @Test func resetPreferencesPreservesBadgeAndReceipts() async throws {
        let harness = try await ConfirmationHarness.make()
        let coordinator = harness.coordinator()
        try await coordinator.confirm(harness.decisionID, operationID: UUID())
        try await coordinator.confirm(harness.decisionID, operationID: UUID(), reaction: .likeIt)
        let before = try await harness.viewerRepository().state(movieID: 1)
        try await harness.viewerRepository().resetProfilePreferences()
        let after = try await harness.viewerRepository().state(movieID: 1)
        #expect(after?.reaction == nil)
        #expect(after?.pickOneProvenance == before?.pickOneProvenance)
        #expect(after?.watchState == .watched)
    }

    private func repository(_ files: InMemoryLocalViewerStateFileStore) -> LocalViewerStateRepository {
        LocalViewerStateRepository(fileStore: files, legacySource: InMemoryLegacyViewerStateSource())
    }
}
