import Foundation
@testable import PickOne
import Testing

@Suite("Local Viewer State v3 migration")
struct LocalViewerStateV3MigrationTests {
    @Test("v2 migrates with a fresh epoch and unchanged semantic state")
    func migrationRoundTrip() async throws {
        let snapshotID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let epochID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let legacyEnvelope = LocalViewerStateTestFixtures.emptyV2Envelope(
            id: snapshotID,
            source: .legacyMigration
        )
        let v2Bytes = try LocalViewerStateTestFixtures.encodedV2(legacyEnvelope)
        let files = InMemoryLocalViewerStateFileStore(activeData: v2Bytes)

        let snapshot = try await LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            suppressionEpochID: { epochID }
        ).snapshot()

        #expect(snapshot.id.rawValue == snapshotID)
        #expect(snapshot.states.isEmpty)
        #expect(snapshot.recommendationSuppressionEpochID.rawValue == epochID)
        #expect(files.previousData == v2Bytes)
        #expect(files.activeData != v2Bytes)

        let active = try #require(files.activeData)
        let decoded = try JSONLocalViewerStateEnvelopeCoder().decode(active)
        guard case let .currentV3(envelope) = decoded else {
            Issue.record("Expected a persisted v3 replacement")
            return
        }
        #expect(envelope.committedStateSnapshotID == legacyEnvelope.committedStateSnapshotID)
        #expect(envelope.viewerProfileState == legacyEnvelope.viewerProfileState)
        #expect(envelope.viewerMovieStates == legacyEnvelope.viewerMovieStates)
        #expect(envelope.migrationRecord == legacyEnvelope.migrationRecord)
        #expect(envelope.recommendationSuppressionEpochID == epochID)
    }

    @Test("failed v3 replacement leaves exact valid v2 bytes active")
    func failedReplacement() async throws {
        let snapshotID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let v2Bytes = try LocalViewerStateTestFixtures.encodedV2(
            LocalViewerStateTestFixtures.emptyV2Envelope(id: snapshotID)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: v2Bytes)
        files.rejectActiveReplacement = true

        await #expect(throws: ViewerMovieStateRepositoryError.replacementFailure) {
            _ = try await LocalViewerStateRepository(
                fileStore: files,
                legacySource: InMemoryLegacyViewerStateSource()
            ).snapshot()
        }

        #expect(files.activeData == v2Bytes)
    }

    @Test("sanitized blocked shape preserves 47 watched facts")
    func blockedShape() async throws {
        let snapshotID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let base = LocalViewerStateTestFixtures.emptyV2Envelope(id: snapshotID)
        let watched = (1 ... 47).map { offset in
            ViewerMovieStateV2DTO(
                movieID: 2000 + offset,
                title: "Sanitized watched \(offset)",
                releaseYear: 2000 + offset % 20,
                posterPath: nil,
                watchState: "watched",
                preference: nil,
                watchlistAddedAt: nil,
                stateChangedAt: LocalViewerStateTestFixtures.date
            )
        }
        let legacyEnvelope = LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: base.envelopeSchemaVersion,
            committedStateSnapshotID: base.committedStateSnapshotID,
            viewerProfileState: base.viewerProfileState,
            viewerMovieStates: watched,
            migrationRecord: base.migrationRecord
        )
        let files = try InMemoryLocalViewerStateFileStore(
            activeData: LocalViewerStateTestFixtures.encodedV2(legacyEnvelope)
        )

        let snapshot = try await LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource()
        ).snapshot()

        #expect(snapshot.states.count == 47)
        #expect(snapshot.states.allSatisfy { $0.watchState.isWatched })
    }
}
