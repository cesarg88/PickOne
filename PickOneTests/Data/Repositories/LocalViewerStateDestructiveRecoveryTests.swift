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
        #expect(await repository.destructiveRecoveryAvailability() == .available)

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

    @Test("read failure exposes retry without destructive recovery")
    func readFailureDoesNotAuthorizeReset() async throws {
        let files = InMemoryLocalViewerStateFileStore()
        files.rejectActiveRead = true
        let legacy = InMemoryLegacyViewerStateSource()
        let repository = makeRepository(files: files, legacy: legacy, ids: [])

        #expect(await repository.loadState() == .recovery(.loadFailure))
        #expect(await repository.destructiveRecoveryAvailability() == .unavailable)

        files.rejectActiveRead = false
        await #expect(throws: ViewerStateDestructiveRecoveryError.stateIsRecoverable) {
            try await repository.resetUnrecoverableViewerState()
        }
    }

    @Test("quarantine failure exposes retry without destructive recovery")
    func quarantineFailureDoesNotAuthorizeReset() async throws {
        let invalid = Data("invalid-active".utf8)
        let files = InMemoryLocalViewerStateFileStore(activeData: invalid)
        files.rejectQuarantine = true
        let legacy = InMemoryLegacyViewerStateSource()
        let repository = makeRepository(files: files, legacy: legacy, ids: [])

        #expect(await repository.loadState() == .recovery(.quarantineFailure))
        #expect(await repository.destructiveRecoveryAvailability() == .unavailable)

        files.rejectQuarantine = false
        await #expect(throws: ViewerStateDestructiveRecoveryError.stateIsRecoverable) {
            try await repository.resetUnrecoverableViewerState()
        }
        #expect(files.activeData == invalid)
    }

    @Test("replacement failure exposes retry without destructive recovery")
    func replacementFailureDoesNotAuthorizeReset() async throws {
        let oldID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let recoveredID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let invalid = Data("invalid-active".utf8)
        let previous = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: oldID)
        )
        let files = InMemoryLocalViewerStateFileStore(
            activeData: invalid,
            previousData: previous
        )
        files.rejectActiveReplacement = true
        let legacy = InMemoryLegacyViewerStateSource()
        let repository = makeRepository(
            files: files,
            legacy: legacy,
            ids: [recoveredID]
        )

        #expect(await repository.loadState() == .recovery(.replacementFailure))
        #expect(await repository.destructiveRecoveryAvailability() == .unavailable)

        files.rejectActiveReplacement = false
        await #expect(throws: ViewerStateDestructiveRecoveryError.stateIsRecoverable) {
            try await repository.resetUnrecoverableViewerState()
        }
        #expect(files.activeData == invalid)
        #expect(files.previousData == previous)
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
