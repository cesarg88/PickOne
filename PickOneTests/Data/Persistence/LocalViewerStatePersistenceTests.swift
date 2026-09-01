import Foundation
@testable import PickOne
import Synchronization
import Testing

@Suite("Local Viewer State persistence", .serialized)
struct LocalViewerStatePersistenceTests {
    @Test("v3 envelope round trips with stable dates and sorted JSON keys")
    func envelopeRoundTrip() throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let state = try ViewerMovieState(
            movieID: 100,
            displayMetadata: LocalViewerStateTestFixtures.metadata(),
            watchState: .watched,
            preference: .reaction(.itWasOkay),
            watchlistIntent: nil,
            stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000.125)
        )
        let base = LocalViewerStateTestFixtures.emptyEnvelope(id: id)
        let envelope = LocalViewerStateEnvelopeMapper().replacingStates(
            in: base,
            snapshotID: id,
            states: [state]
        )
        let coder = JSONLocalViewerStateEnvelopeCoder()

        let data = try coder.encode(envelope)
        let decoded = try coder.decode(data)

        #expect(decoded == .currentV3(envelope))
        #expect(try LocalViewerStateEnvelopeMapper().snapshot(from: envelope).states == [state])
        let json = try #require(String(bytes: data, encoding: .utf8))
        #expect(json.hasPrefix("{\"committedStateSnapshotID\""))
    }

    @Test("corrupt and unsupported schemas remain distinct")
    func codingFailures() {
        let coder = JSONLocalViewerStateEnvelopeCoder()

        #expect(throws: LocalViewerStateCodingError.corruptData) {
            _ = try coder.decode(Data("not-json".utf8))
        }
        #expect(throws: LocalViewerStateCodingError.unsupportedSchema) {
            _ = try coder.decode(Data(#"{"envelopeSchemaVersion":4}"#.utf8))
        }
    }

    @Test("schema-valid duplicate movie identities fail semantic validation")
    func duplicateMovieIDs() throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let dto = ViewerMovieStateV2DTO(
            movieID: 100,
            title: "Arrival",
            releaseYear: 2016,
            posterPath: nil,
            watchState: "watched",
            preference: nil,
            watchlistAddedAt: nil,
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let base = LocalViewerStateTestFixtures.emptyEnvelope(id: id)
        let envelope = LocalViewerStateEnvelopeV3DTO(
            envelopeSchemaVersion: base.envelopeSchemaVersion,
            committedStateSnapshotID: base.committedStateSnapshotID,
            recommendationSuppressionEpochID: base.recommendationSuppressionEpochID,
            viewerProfileState: base.viewerProfileState,
            viewerMovieStates: [dto, dto],
            migrationRecord: base.migrationRecord
        )

        #expect(throws: ViewerMovieStateSnapshotValidationError.duplicateMovieID(100)) {
            _ = try LocalViewerStateEnvelopeMapper().snapshot(from: envelope)
        }
    }

    @Test("Application Support store keeps active, previous, and unique quarantine files independent")
    func applicationSupportStore() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "PickOne-LocalViewerState-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let firstName = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondName = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let names = SequenceUUIDGenerator([firstName, secondName])
        let store = try ApplicationSupportViewerStateStore(
            directoryURL: root,
            quarantineName: { names.next() }
        )
        let active = Data("active".utf8)
        let previous = Data("previous".utf8)
        let invalid = Data("invalid".utf8)

        try store.replaceActive(with: active)
        try store.replacePrevious(with: previous)
        try store.replaceActive(with: Data("active-replacement".utf8))
        try store.quarantine(invalid, source: .active)
        try store.quarantine(invalid, source: .active)

        #expect(try store.readActive() == Data("active-replacement".utf8))
        #expect(try store.readPrevious() == previous)
        try store.removePrevious()
        #expect(try store.readPrevious() == nil)
        let quarantine = root.appending(path: "Quarantine", directoryHint: .isDirectory)
        let files = try FileManager.default.contentsOfDirectory(
            at: quarantine,
            includingPropertiesForKeys: nil
        )
        #expect(files.count == 2)
        #expect(try files.map { try Data(contentsOf: $0) } == [invalid, invalid])

        try store.removeAllViewerState()
        #expect(try store.readActive() == nil)
        #expect(try store.readPrevious() == nil)
        #expect(!FileManager.default.fileExists(atPath: root.path(percentEncoded: false)))
    }

    @Test("Application Support volume replaces an active file after copying it to previous")
    func applicationSupportVolumeReplacement() throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = support.appending(
            path: "PickOne-LocalViewerState-Test-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ApplicationSupportViewerStateStore(directoryURL: root)
        let original = Data("original".utf8)
        let replacement = Data("replacement".utf8)

        try store.replaceActive(with: original)
        let active = try #require(try store.readActive())
        try store.replacePrevious(with: active)
        try store.replaceActive(with: replacement)

        #expect(try store.readActive() == replacement)
        #expect(try store.readPrevious() == original)
        let remainingNames = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent).sorted()
        #expect(remainingNames == ["viewer-state-v2.json", "viewer-state-v2.previous.json"])
    }

    @Test("post-commit backup cleanup failure does not report replacement failure")
    func postCommitBackupCleanupFailure() throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = support.appending(
            path: "PickOne-LocalViewerState-Cleanup-Test-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let cleanupAttempts = Mutex(0)
        let store = try ApplicationSupportViewerStateStore(
            directoryURL: root,
            removeReplacementBackup: { _ in
                cleanupAttempts.withLock { $0 += 1 }
                throw LocalViewerStateTestError.rejected
            }
        )
        let original = Data("original".utf8)
        let replacement = Data("replacement".utf8)

        try store.replaceActive(with: original)
        try store.replaceActive(with: replacement)

        #expect(try store.readActive() == replacement)
        #expect(cleanupAttempts.withLock { $0 } == 1)
    }

    @Test("destructive cleanup removes abandoned viewer-state artifacts only")
    func destructiveCleanupRemovesEveryStoreArtifact() throws {
        let parent = FileManager.default.temporaryDirectory.appending(
            path: "PickOne-Destructive-Cleanup-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let root = parent.appending(path: "ViewerState", directoryHint: .isDirectory)
        let outside = parent.appending(path: "outside-viewer-data.json")
        defer { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: false
        )
        let outsideBytes = Data("outside".utf8)
        try outsideBytes.write(to: outside, options: .withoutOverwriting)
        let store = try ApplicationSupportViewerStateStore(
            directoryURL: root,
            removeReplacementBackup: { _ in
                throw LocalViewerStateTestError.rejected
            }
        )
        try store.replaceActive(with: Data("recoverable-original".utf8))
        try store.replaceActive(with: Data("committed-replacement".utf8))
        let staging = root.appending(
            path: ".abandoned-staging",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: staging,
            withIntermediateDirectories: false
        )
        try Data("staged-viewer-data".utf8).write(
            to: staging.appending(path: "viewer-state-v2.json"),
            options: .withoutOverwriting
        )
        let artifactNames = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent)
        #expect(artifactNames.contains { $0.hasSuffix("-replacement-backup.json") })
        #expect(artifactNames.contains(".abandoned-staging"))

        try store.removeAllViewerState()

        #expect(!FileManager.default.fileExists(atPath: root.path(percentEncoded: false)))
        #expect(try Data(contentsOf: outside) == outsideBytes)
    }

    @Test("a v3 fixture remains readable after repository recreation")
    func laterBuildCompatibilityFixture() async throws {
        let id = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let fixture = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: id, source: .legacyMigration)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: fixture)

        let first = try await LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource()
        ).snapshot()
        let laterBuild = try await LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource()
        ).snapshot()

        #expect(first == laterBuild)
        #expect(files.activeReplacementCount == 0)
    }
}
