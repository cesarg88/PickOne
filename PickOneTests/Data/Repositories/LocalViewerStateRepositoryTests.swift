import Foundation
@testable import PickOne
import Testing

@Suite("Local Viewer State repository")
struct LocalViewerStateRepositoryTests {
    @Test("a fresh install creates an explicit valid empty envelope")
    func freshInstall() async throws {
        let fixedID = try #require(
            UUID(uuidString: "10000000-0000-0000-0000-000000000001")
        )
        let files = InMemoryLocalViewerStateFileStore()
        let repository = LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            snapshotID: { fixedID },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let snapshot = try await repository.snapshot()

        #expect(snapshot.states.isEmpty)
        #expect(snapshot.id.rawValue.uuidString == "10000000-0000-0000-0000-000000000001")
        #expect(files.activeData != nil)
        #expect(files.previousData == nil)
    }

    @Test("a semantic mutation rotates the valid active envelope and snapshot identity")
    func semanticMutation() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let files = InMemoryLocalViewerStateFileStore()
        let ids = SequenceUUIDGenerator([firstID, secondID])
        let repository = makeRepository(files: files, ids: ids)
        let initial = try await repository.snapshot()
        let initialBytes = try #require(files.activeData)

        let change = try await repository.apply(
            ViewerMovieStateTransition(movieID: 100, action: .assignReaction(.loveIt)),
            metadata: LocalViewerStateTestFixtures.metadata()
        )

        #expect(change.impact == .tasteChanged)
        #expect(change.snapshotID.rawValue == secondID)
        #expect(change.state?.reaction == .loveIt)
        #expect(files.previousData == initialBytes)
        #expect(files.activeData != initialBytes)
        #expect(initial.id.rawValue == firstID)
    }

    @Test("a semantic mutation refuses to reuse its current snapshot identity")
    func semanticMutationIdentityIsFresh() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let active = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: firstID)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        let repository = makeRepository(
            files: files,
            ids: SequenceUUIDGenerator([firstID, secondID])
        )

        let change = try await repository.apply(
            ViewerMovieStateTransition(movieID: 100, action: .markWatched),
            metadata: LocalViewerStateTestFixtures.metadata()
        )

        #expect(change.snapshotID.rawValue == secondID)
    }

    @Test("an unchanged repeated action preserves envelope bytes and timestamps")
    func semanticNoOp() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let ids = SequenceUUIDGenerator([firstID, secondID])
        let files = InMemoryLocalViewerStateFileStore()
        let repository = makeRepository(files: files, ids: ids)
        let transition = ViewerMovieStateTransition(
            movieID: 100,
            action: .assignReaction(.loveIt)
        )
        let metadata = try LocalViewerStateTestFixtures.metadata()
        let first = try await repository.apply(transition, metadata: metadata)
        let activeBytes = files.activeData
        let previousBytes = files.previousData
        let activeReplacementCount = files.activeReplacementCount
        let previousReplacementCount = files.previousReplacementCount

        let repeated = try await repository.apply(transition, metadata: metadata)

        #expect(repeated.impact == .none)
        #expect(repeated.snapshotID == first.snapshotID)
        #expect(repeated.state?.stateChangedAt == first.state?.stateChangedAt)
        #expect(files.activeData == activeBytes)
        #expect(files.previousData == previousBytes)
        #expect(files.activeReplacementCount == activeReplacementCount)
        #expect(files.previousReplacementCount == previousReplacementCount)
    }

    @Test("metadata refresh persists without changing semantic identity or order time")
    func metadataRefresh() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let ids = SequenceUUIDGenerator([firstID, secondID])
        let files = InMemoryLocalViewerStateFileStore()
        let repository = makeRepository(files: files, ids: ids)
        let transition = ViewerMovieStateTransition(movieID: 100, action: .markWatched)
        let first = try await repository.apply(
            transition,
            metadata: LocalViewerStateTestFixtures.metadata()
        )

        let refreshed = try await repository.apply(
            transition,
            metadata: LocalViewerStateTestFixtures.metadata(title: "La llegada")
        )

        #expect(refreshed.impact == .none)
        #expect(refreshed.snapshotID == first.snapshotID)
        #expect(refreshed.state?.stateChangedAt == first.state?.stateChangedAt)
        #expect(refreshed.state?.displayMetadata.title == "La llegada")
    }

    @Test("repository recreation reads the same persisted snapshot")
    func relaunch() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let ids = SequenceUUIDGenerator([firstID, secondID])
        let files = InMemoryLocalViewerStateFileStore()
        let repository = makeRepository(files: files, ids: ids)
        _ = try await repository.apply(
            ViewerMovieStateTransition(movieID: 100, action: .markWatched),
            metadata: LocalViewerStateTestFixtures.metadata()
        )

        let relaunched = makeRepository(files: files, ids: SequenceUUIDGenerator([]))

        #expect(try await relaunched.snapshot() == repository.snapshot())
    }

    @Test("invalid identities and transitions are typed rejections")
    func typedRejections() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let repository = makeRepository(
            files: InMemoryLocalViewerStateFileStore(),
            ids: SequenceUUIDGenerator([firstID])
        )

        await #expect(throws: ViewerMovieStateRepositoryError.invalidMovieID) {
            _ = try await repository.state(movieID: 0)
        }
        _ = try await repository.apply(
            ViewerMovieStateTransition(movieID: 100, action: .markWatched),
            metadata: LocalViewerStateTestFixtures.metadata()
        )
        await #expect(
            throws: ViewerMovieStateRepositoryError.invalidTransition(
                .notInterestedRequiresUnwatched
            )
        ) {
            _ = try await repository.apply(
                ViewerMovieStateTransition(movieID: 100, action: .setNotInterested),
                metadata: LocalViewerStateTestFixtures.metadata()
            )
        }
    }

    @Test("concurrent transitions serialize and receive unique committed identities")
    func concurrentTransitions() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let thirdID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.thirdID)
        let repository = makeRepository(
            files: InMemoryLocalViewerStateFileStore(),
            ids: SequenceUUIDGenerator([firstID, secondID, thirdID])
        )
        let firstTransition = ViewerMovieStateTransition(movieID: 100, action: .markWatched)
        let secondTransition = ViewerMovieStateTransition(movieID: 200, action: .markWatched)
        let firstMetadata = try LocalViewerStateTestFixtures.metadata(title: "First")
        let secondMetadata = try LocalViewerStateTestFixtures.metadata(title: "Second")

        async let first = repository.apply(firstTransition, metadata: firstMetadata)
        async let second = repository.apply(secondTransition, metadata: secondMetadata)
        let changes = try await [first, second]
        let snapshot = try await repository.snapshot()

        #expect(Set(changes.map(\.snapshotID.rawValue)) == [secondID, thirdID])
        #expect(snapshot.states.map(\.movieID) == [100, 200])
    }

    @Test("previous-copy failure leaves the active envelope untouched")
    func previousCopyFailure() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let active = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: firstID)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        files.rejectPreviousReplacement = true
        let repository = makeRepository(files: files, ids: SequenceUUIDGenerator([secondID]))

        await #expect(throws: ViewerMovieStateRepositoryError.previousCopyFailure) {
            _ = try await repository.apply(
                ViewerMovieStateTransition(movieID: 100, action: .markWatched),
                metadata: LocalViewerStateTestFixtures.metadata()
            )
        }
        #expect(files.activeData == active)
        #expect(files.previousData == nil)
    }

    @Test("active replacement failure preserves a readable active and previous copy")
    func activeReplacementFailure() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let active = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: firstID)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        files.rejectActiveReplacement = true
        let repository = makeRepository(files: files, ids: SequenceUUIDGenerator([secondID]))

        await #expect(throws: ViewerMovieStateRepositoryError.replacementFailure) {
            _ = try await repository.apply(
                ViewerMovieStateTransition(movieID: 100, action: .markWatched),
                metadata: LocalViewerStateTestFixtures.metadata()
            )
        }
        #expect(files.activeData == active)
        #expect(files.previousData == active)
    }

    @Test("encoding failure leaves both persisted envelopes untouched")
    func encodingFailure() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let secondID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.secondID)
        let active = try LocalViewerStateTestFixtures.encoded(
            LocalViewerStateTestFixtures.emptyEnvelope(id: firstID)
        )
        let files = InMemoryLocalViewerStateFileStore(activeData: active)
        let repository = LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            coder: FailingLocalViewerStateEncoder(),
            snapshotID: { secondID },
            now: { LocalViewerStateTestFixtures.date }
        )

        await #expect(throws: ViewerMovieStateRepositoryError.encodingFailure) {
            _ = try await repository.apply(
                ViewerMovieStateTransition(movieID: 100, action: .markWatched),
                metadata: LocalViewerStateTestFixtures.metadata()
            )
        }
        #expect(files.activeData == active)
        #expect(files.previousData == nil)
    }

    private func makeRepository(
        files: InMemoryLocalViewerStateFileStore,
        ids: SequenceUUIDGenerator
    ) -> LocalViewerStateRepository {
        LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            snapshotID: { ids.next() },
            now: { LocalViewerStateTestFixtures.date }
        )
    }
}
