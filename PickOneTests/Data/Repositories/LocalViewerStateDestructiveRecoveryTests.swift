import Foundation
@testable import PickOne
import Testing

@Suite("Local viewer-state destructive recovery")
struct LocalViewerStateDestructiveRecoveryTests {
    @Test("destructive recovery removes every viewer-state source and relaunches explicitly absent")
    func destructiveRecoveryScope() async throws {
        let failedMigrationID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let resetID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let files = InMemoryLocalViewerStateFileStore(
            activeData: Data("invalid-active".utf8),
            previousData: Data("invalid-previous".utf8)
        )
        let legacy = InMemoryLegacyViewerStateSource(
            profileData: Data("invalid-legacy-profile".utf8)
        )
        let repository = makeRepository(
            files: files,
            legacy: legacy,
            ids: [failedMigrationID, resetID]
        )

        #expect(await repository.loadState() == .recovery(.migrationFailure))

        try await repository.resetUnrecoverableViewerState()

        #expect(files.previousData == nil)
        #expect(files.quarantinedItems.isEmpty)
        #expect(legacy.profileData == nil)
        #expect(legacy.watchlistData == nil)
        let active = try #require(files.activeData)
        let envelope = try JSONLocalViewerStateEnvelopeCoder().decode(active)
        #expect(envelope.committedStateSnapshotID == resetID)
        #expect(envelope.viewerProfileState.completedProfile == nil)
        #expect(envelope.viewerProfileState.profileDraft == nil)
        #expect(envelope.viewerMovieStates.isEmpty)
        #expect(envelope.migrationRecord.source == .freshInstall)

        let relaunched = makeRepository(files: files, legacy: legacy, ids: [])
        #expect(try await relaunched.snapshot().states.isEmpty)
        #expect(await relaunched.loadProfileState() == .absent)
    }

    @Test("destructive recovery is unavailable while any valid state can load")
    func destructiveRecoveryRequiresTotalFailure() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let files = try InMemoryLocalViewerStateFileStore(
            activeData: LocalViewerStateTestFixtures.encoded(
                LocalViewerStateTestFixtures.emptyEnvelope(id: id)
            )
        )
        let legacy = InMemoryLegacyViewerStateSource()
        let repository = makeRepository(files: files, legacy: legacy, ids: [])

        await #expect(throws: ViewerStateDestructiveRecoveryError.stateIsRecoverable) {
            try await repository.resetUnrecoverableViewerState()
        }
        #expect(files.activeData != nil)
    }

    private func makeRepository(
        files: InMemoryLocalViewerStateFileStore,
        legacy: InMemoryLegacyViewerStateSource,
        ids: [UUID]
    ) -> LocalViewerStateRepository {
        let generator = SequenceUUIDGenerator(ids)
        return LocalViewerStateRepository(
            fileStore: files,
            legacySource: legacy,
            legacyResetter: legacy,
            snapshotID: { generator.next() },
            now: { LocalViewerStateTestFixtures.date }
        )
    }
}
