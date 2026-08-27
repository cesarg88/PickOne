import Foundation
@testable import PickOne
import Testing

@Suite("Local Viewer State recovery")
struct LocalViewerStateRecoveryTests {
    @Test("a valid active envelope wins without consulting fallback sources")
    func activePrecedence() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let active = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: id)
        )
        let files = InMemoryLocalViewerStateFileStore(
            activeData: active,
            previousData: Data("invalid-previous".utf8)
        )
        let legacy = InMemoryLegacyViewerStateSource()
        legacy.rejectReads = true

        let snapshot = try await makeRepository(
            files: files,
            legacy: legacy,
            ids: []
        ).snapshot()

        #expect(snapshot.id.rawValue == id)
        #expect(files.quarantinedItems.isEmpty)
        #expect(files.activeReplacementCount == 0)
    }

    @Test("corrupt active bytes are quarantined before previous state is republished")
    func previousRecovery() async throws {
        let oldID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let recoveredID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let corrupt = Data("not-json".utf8)
        let previous = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: oldID)
        )
        let files = InMemoryLocalViewerStateFileStore(
            activeData: corrupt,
            previousData: previous
        )
        let legacy = InMemoryLegacyViewerStateSource()
        legacy.rejectReads = true
        let repository = makeRepository(
            files: files,
            legacy: legacy,
            ids: [recoveredID]
        )

        let snapshot = try await repository.snapshot()

        #expect(snapshot.id.rawValue == recoveredID)
        #expect(files.quarantinedItems == [
            LocalViewerStateQuarantineItem(source: .active, data: corrupt),
        ])
        #expect(files.previousData == previous)
        let active = try #require(files.activeData)
        let envelope = try JSONLocalViewerStateEnvelopeCoder().decode(active)
        #expect(envelope.migrationRecord.source == .previousRecovery)
        #expect(await repository.successfulRecoveryNotice() == .olderSnapshot)
    }

    @Test("previous recovery always publishes a fresh non-reused snapshot identity")
    func previousRecoveryIdentity() async throws {
        let oldID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let recoveredID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let previous = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: oldID)
        )
        let files = InMemoryLocalViewerStateFileStore(previousData: previous)

        let snapshot = try await makeRepository(
            files: files,
            ids: [oldID, recoveredID]
        ).snapshot()

        #expect(snapshot.id.rawValue == recoveredID)
        #expect(snapshot.id.rawValue != oldID)
    }

    @Test("legacy recovery clears invalid previous bytes and remains valid after relaunch")
    func legacyRecoveryClearsInvalidPrevious() async throws {
        let recoveredID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let invalid = Data("same-invalid-bytes".utf8)
        let watchlistData = try JSONEncoder().encode([watchlistItem(movieID: 42)])
        let files = InMemoryLocalViewerStateFileStore(
            activeData: invalid,
            previousData: invalid
        )
        let legacy = InMemoryLegacyViewerStateSource(watchlistData: watchlistData)
        let repository = makeRepository(files: files, legacy: legacy, ids: [recoveredID])

        let snapshot = try await repository.snapshot()

        #expect(snapshot.states.map(\.movieID) == [42])
        #expect(files.quarantinedItems == [
            LocalViewerStateQuarantineItem(source: .active, data: invalid),
            LocalViewerStateQuarantineItem(source: .previous, data: invalid),
        ])
        #expect(files.previousData == nil)
        let envelope = try JSONLocalViewerStateEnvelopeCoder().decode(
            #require(files.activeData)
        )
        #expect(envelope.migrationRecord.source == .legacyRecovery)

        legacy.rejectReads = true
        let relaunchedSnapshot = try await makeRepository(
            files: files,
            legacy: legacy,
            ids: []
        ).snapshot()

        #expect(relaunchedSnapshot == snapshot)
        #expect(files.previousData == nil)
        #expect(files.quarantinedItems == [
            LocalViewerStateQuarantineItem(source: .active, data: invalid),
            LocalViewerStateQuarantineItem(source: .previous, data: invalid),
        ])
    }

    @Test("previous cleanup failure blocks legacy publication and preserves invalid sources")
    func previousCleanupFailure() async throws {
        let recoveredID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let invalid = Data("same-invalid-bytes".utf8)
        let watchlistData = try JSONEncoder().encode([watchlistItem(movieID: 42)])
        let files = InMemoryLocalViewerStateFileStore(
            activeData: invalid,
            previousData: invalid
        )
        files.rejectPreviousRemoval = true
        let legacy = InMemoryLegacyViewerStateSource(watchlistData: watchlistData)

        #expect(
            await makeRepository(
                files: files,
                legacy: legacy,
                ids: [recoveredID]
            ).loadState() == .recovery(.replacementFailure)
        )
        #expect(files.activeData == invalid)
        #expect(files.previousData == invalid)
        #expect(files.activeReplacementCount == 0)
        #expect(files.quarantinedItems == [
            LocalViewerStateQuarantineItem(source: .active, data: invalid),
            LocalViewerStateQuarantineItem(source: .previous, data: invalid),
        ])
    }

    @Test("unsupported active schema remains distinct when no recovery source exists")
    func unsupportedSchema() async {
        let unsupported = Data(#"{"envelopeSchemaVersion":99}"#.utf8)
        let files = InMemoryLocalViewerStateFileStore(activeData: unsupported)
        let repository = makeRepository(files: files, ids: [])

        #expect(await repository.loadState() == .recovery(.unsupportedSchema))
        #expect(files.quarantinedItems == [
            LocalViewerStateQuarantineItem(source: .active, data: unsupported),
        ])
        #expect(files.activeData == unsupported)
    }

    @Test("unsupported nested profile schema is quarantined as incompatible")
    func unsupportedProfileSchema() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let base = LocalViewerStateTestFixtures.emptyEnvelope(id: id)
        let envelope = LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: base.envelopeSchemaVersion,
            committedStateSnapshotID: base.committedStateSnapshotID,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: CompletedViewerProfileV2DTO(
                    profileSchemaVersion: 99,
                    lastCompletedCatalogReference: CalibrationCatalogReferenceV2DTO(
                        schemaVersion: 1,
                        catalogID: "es-household-calibration",
                        version: 1,
                        regionCode: "ES",
                        localeIdentifier: "es-ES"
                    ),
                    regionCode: "ES",
                    selectedProviderIDs: [8]
                ),
                profileDraft: nil
            ),
            viewerMovieStates: [],
            migrationRecord: base.migrationRecord
        )
        let incompatible = try JSONLocalViewerStateEnvelopeCoder().encode(envelope)
        let files = InMemoryLocalViewerStateFileStore(activeData: incompatible)

        #expect(
            await makeRepository(files: files, ids: []).loadState()
                == .recovery(.unsupportedSchema)
        )
        #expect(files.quarantinedItems.first?.data == incompatible)
    }

    @Test("completed profile catalog schemas remain distinct from corrupt references")
    func completedProfileCatalogSchemaClassification() async throws {
        let unsupportedID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let corruptID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.secondID
        )
        let unsupported = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.envelope(
                id: unsupportedID,
                completedProfile: LocalViewerStateTestFixtures.completedProfile(
                    catalogReference: LocalViewerStateTestFixtures.catalogReference(
                        schemaVersion: 99
                    )
                )
            )
        )
        let corrupt = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.envelope(
                id: corruptID,
                completedProfile: LocalViewerStateTestFixtures.completedProfile(
                    catalogReference: LocalViewerStateTestFixtures.catalogReference(
                        catalogID: ""
                    )
                )
            )
        )
        let unsupportedFiles = InMemoryLocalViewerStateFileStore(activeData: unsupported)
        let corruptFiles = InMemoryLocalViewerStateFileStore(activeData: corrupt)

        #expect(
            await makeRepository(files: unsupportedFiles, ids: []).loadState()
                == .recovery(.unsupportedSchema)
        )
        #expect(
            await makeRepository(files: corruptFiles, ids: []).loadState()
                == .recovery(.corruptData)
        )
        #expect(unsupportedFiles.quarantinedItems.first?.data == unsupported)
        #expect(corruptFiles.quarantinedItems.first?.data == corrupt)
    }

    @Test("frozen draft catalog schemas remain distinct from corrupt references")
    func frozenDraftCatalogSchemaClassification() async throws {
        let unsupportedID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let corruptID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.secondID
        )
        let unsupported = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.envelope(
                id: unsupportedID,
                profileDraft: LocalViewerStateTestFixtures.profileDraft(
                    catalogReference: LocalViewerStateTestFixtures.catalogReference(
                        schemaVersion: 99
                    )
                )
            )
        )
        let corrupt = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.envelope(
                id: corruptID,
                profileDraft: LocalViewerStateTestFixtures.profileDraft(
                    catalogReference: LocalViewerStateTestFixtures.catalogReference(
                        catalogID: ""
                    )
                )
            )
        )
        let unsupportedFiles = InMemoryLocalViewerStateFileStore(activeData: unsupported)
        let corruptFiles = InMemoryLocalViewerStateFileStore(activeData: corrupt)

        #expect(
            await makeRepository(files: unsupportedFiles, ids: []).loadState()
                == .recovery(.unsupportedSchema)
        )
        #expect(
            await makeRepository(files: corruptFiles, ids: []).loadState()
                == .recovery(.corruptData)
        )
        #expect(unsupportedFiles.quarantinedItems.first?.data == unsupported)
        #expect(corruptFiles.quarantinedItems.first?.data == corrupt)
    }

    @Test("quarantine failure blocks replacement and preserves the original active bytes")
    func quarantineFailure() async {
        let corrupt = Data("not-json".utf8)
        let files = InMemoryLocalViewerStateFileStore(activeData: corrupt)
        files.rejectQuarantine = true

        #expect(
            await makeRepository(files: files, ids: []).loadState()
                == .recovery(.quarantineFailure)
        )
        #expect(files.activeData == corrupt)
        #expect(files.quarantinedItems.isEmpty)
        #expect(files.activeReplacementCount == 0)
    }

    @Test("active and previous read failures never become clean empty state")
    func readFailures() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let activeReadFailure = InMemoryLocalViewerStateFileStore()
        activeReadFailure.rejectActiveRead = true
        let previousReadFailure = InMemoryLocalViewerStateFileStore(
            activeData: Data("invalid".utf8)
        )
        previousReadFailure.rejectPreviousRead = true

        #expect(
            await makeRepository(files: activeReadFailure, ids: [id]).loadState()
                == .recovery(.loadFailure)
        )
        #expect(
            await makeRepository(files: previousReadFailure, ids: [id]).loadState()
                == .recovery(.loadFailure)
        )
        #expect(activeReadFailure.activeData == nil)
        #expect(previousReadFailure.activeData == Data("invalid".utf8))
    }

    @Test("failed previous-state publication keeps corrupt active bytes and valid previous bytes")
    func recoveryReplacementFailure() async throws {
        let oldID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let newID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let corrupt = Data("not-json".utf8)
        let previous = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: oldID)
        )
        let files = InMemoryLocalViewerStateFileStore(
            activeData: corrupt,
            previousData: previous
        )
        files.rejectActiveReplacement = true

        #expect(
            await makeRepository(files: files, ids: [newID]).loadState()
                == .recovery(.replacementFailure)
        )
        #expect(files.activeData == corrupt)
        #expect(files.previousData == previous)
        #expect(files.quarantinedItems.first?.data == corrupt)
    }

    @Test("a corrupt present legacy source blocks partial migration")
    func corruptLegacyBlocksMigration() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let validProfile = try JSONViewerProfileEnvelopeCoder().encodeEnvelope(
            ViewerStateEnvelopeV1DTO(
                envelopeSchemaVersion: ViewerStateEnvelopeV1DTO.schemaVersion,
                completedProfile: nil,
                profileDraft: nil
            )
        )
        let validWatchlist = try JSONEncoder().encode([watchlistItem(movieID: 42)])
        let sources = [
            InMemoryLegacyViewerStateSource(
                profileData: Data("invalid-profile".utf8),
                watchlistData: validWatchlist
            ),
            InMemoryLegacyViewerStateSource(
                profileData: validProfile,
                watchlistData: Data("invalid-watchlist".utf8)
            ),
        ]

        for legacy in sources {
            let files = InMemoryLocalViewerStateFileStore()
            #expect(
                await makeRepository(files: files, legacy: legacy, ids: [id]).loadState()
                    == .recovery(.migrationFailure)
            )
            #expect(files.activeData == nil)
            #expect(files.previousData == nil)
        }
    }

    @Test("legacy source read failure remains a migration failure")
    func legacyReadFailure() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let legacy = InMemoryLegacyViewerStateSource()
        legacy.rejectReads = true

        #expect(
            await makeRepository(
                files: InMemoryLocalViewerStateFileStore(),
                legacy: legacy,
                ids: [id]
            ).loadState() == .recovery(.migrationFailure)
        )
    }

    private func makeRepository(
        files: InMemoryLocalViewerStateFileStore,
        legacy: InMemoryLegacyViewerStateSource = InMemoryLegacyViewerStateSource(),
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

    private func watchlistItem(movieID: Int) -> PersistedWatchlistItem {
        PersistedWatchlistItem(
            movieId: movieID,
            title: "Movie \(movieID)",
            posterPath: "/poster.jpg",
            releaseYear: 2024,
            rating: 8,
            addedAt: LocalViewerStateTestFixtures.date,
            isWatched: false
        )
    }
}
