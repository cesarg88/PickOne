import Foundation
@testable import PickOne
import Synchronization
import Testing

struct ViewingConfirmationRecoveryTests {
    @Test(arguments: Array(1 ... 8), [false, true])
    func everyJournalWriteResumesAfterRecreation(failureBoundary: Int, capturesReaction: Bool) async throws {
        let harness = try await ConfirmationHarness.make()
        if capturesReaction { try await harness.coordinator().confirm(harness.decisionID, operationID: UUID()) }
        let reaction: MovieReaction? = capturesReaction ? .likeIt : nil
        harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + failureBoundary
        let operationID = UUID()
        do { try await harness.coordinator().confirm(harness.decisionID, operationID: operationID, reaction: reaction)
        } catch {}
        harness.decisionFiles.failAtWrite = nil
        let coordinator = harness.coordinator()
        try await coordinator.confirm(harness.decisionID, operationID: operationID, reaction: reaction)
        let state = try await coordinator.snapshot()
        #expect(state.decisions.count == 1)
        #expect(state.decisions.first?.status == .confirmedWatched)
        #expect(state.confirmationOperations.count == (capturesReaction ? 2 : 1))
        #expect(state.confirmationOperations.first?.stage == .completed)
        let movie = try await harness.viewerRepository().state(movieID: 1)
        #expect(movie?.watchState == .watched)
        #expect(movie?.pickOneProvenance != nil)
        if !capturesReaction { #expect(movie?.pickOneProvenance?.confirmationOperationID == operationID) }
        #expect(movie?.reaction == reaction)
        #expect(state.decisions.first?.satisfaction == reaction)
    }

    @Test(arguments: ["active", "previous"])
    func viewerWriteFailureNeverClaimsProvenance(boundary: String) async throws {
        let harness = try await ConfirmationHarness.make()
        _ = try await harness.viewerRepository().snapshot()
        harness.viewerFiles.rejectActiveReplacement = boundary == "active"
        harness.viewerFiles.rejectPreviousReplacement = boundary == "previous"
        await #expect(throws: (any Error).self) {
            try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        }
        let state = try await harness.coordinator().snapshot()
        #expect(state.decisions.first?.status == .active)
        #expect(try await harness.viewerRepository().state(movieID: 1) == nil)
        harness.viewerFiles.rejectActiveReplacement = false
        harness.viewerFiles.rejectPreviousReplacement = false
        try await harness.coordinator().reconcile()
        #expect(try await harness.viewerRepository().state(movieID: 1)?.pickOneProvenance != nil)
    }

    @Test func reactionSnapshotSurvivesLaterEditsAndUnwatchedNeverReplays() async throws {
        let harness = try await ConfirmationHarness.make()
        let confirmationID = UUID()
        try await harness.coordinator().confirm(harness.decisionID, operationID: confirmationID)
        let reactionID = UUID()
        // Fail after the reaction commits but before its committed journal checkpoint.
        harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + 6
        await #expect(throws: (any Error).self) {
            try await harness.coordinator().confirm(harness.decisionID, operationID: reactionID, reaction: .loveIt)
        }
        #expect(try await harness.viewerRepository().state(movieID: 1)?.reaction == .loveIt)
        _ = try await harness.viewerRepository().apply(
            .init(movieID: 1, action: .assignReaction(.didNotLikeIt)),
            metadata: harness.metadata
        )
        harness.decisionFiles.failAtWrite = nil
        try await harness.coordinator().reconcile()
        #expect(try await harness.coordinator().snapshot().decisions.first?.satisfaction == .loveIt)
        #expect(try await harness.viewerRepository().state(movieID: 1)?.reaction == .didNotLikeIt)
        _ = try await harness.viewerRepository().apply(
            .init(movieID: 1, action: .markUnwatched),
            metadata: harness.metadata
        )
        try await harness.coordinator().confirm(harness.decisionID, operationID: confirmationID)
        #expect(try await harness.viewerRepository().state(movieID: 1) == nil)
        #expect(try await harness.coordinator().snapshot().decisions.first?.satisfaction == .loveIt)
    }

    @Test func replayAfterWatchedCommitDoesNotUndoUnwatched() async throws {
        let harness = try await ConfirmationHarness.make()
        harness.decisionFiles.failAtWrite = harness.decisionFiles.writeAttempts + 6
        await #expect(throws: (any Error).self) {
            try await harness.coordinator().confirm(harness.decisionID, operationID: UUID())
        }
        #expect(try await harness.viewerRepository().state(movieID: 1)?.pickOneProvenance != nil)
        _ = try await harness.viewerRepository().apply(
            .init(movieID: 1, action: .markUnwatched),
            metadata: harness.metadata
        )
        harness.decisionFiles.failAtWrite = nil
        try await harness.coordinator().reconcile()
        #expect(try await harness.viewerRepository().state(movieID: 1) == nil)
        #expect(try await harness.coordinator().snapshot().decisions.first?.status == .confirmedWatched)
    }
}

struct ConfirmationHarness: Sendable {
    let decisionFiles: ConfirmationFailureStore
    let viewerFiles: InMemoryLocalViewerStateFileStore
    let decisionID: ViewingDecisionID
    let metadata: MovieFeedbackMetadata
    let now: DecisionMoment

    static func make() async throws -> Self {
        let files = ConfirmationFailureStore()
        let repository = LocalViewingDecisionRepository(store: files)
        let start = DecisionMoment(wall: Date(timeIntervalSince1970: 1000), monotonicSeconds: 0, runtimeID: UUID())
        let card = PickRecommendation(movieID: 1, setID: UUID(), cycleID: UUID(), role: .safeChoice)
        let surface = try ViewingDecisionSurface(recommendations: [card])
        _ = try await repository.apply(.init(action: .pick(card, snapshot: surface, isVisible: false), moment: start))
        let id = try #require(try await repository.snapshot().activeDecision?.id)
        return try Self(
            decisionFiles: files,
            viewerFiles: InMemoryLocalViewerStateFileStore(),
            decisionID: id,
            metadata: MovieFeedbackMetadata(title: "Movie", releaseYear: 2020, posterPath: nil),
            now: DecisionMoment(
                wall: start.wall.addingTimeInterval(12 * 3600),
                monotonicSeconds: 12 * 3600,
                runtimeID: start.runtimeID
            )
        )
    }

    func viewerRepository() -> LocalViewerStateRepository {
        LocalViewerStateRepository(fileStore: viewerFiles, legacySource: InMemoryLegacyViewerStateSource())
    }

    func coordinator() -> ConfirmViewingDecision {
        ConfirmViewingDecision(
            decisions: LocalViewingDecisionRepository(store: decisionFiles),
            viewerState: viewerRepository(),
            metadata: { _ in metadata },
            moment: { now }
        )
    }
}

final class ConfirmationFailureStore: ViewingDecisionFileStore {
    let base = MemoryViewingDecisionStore()
    private struct State { var attempts = 0; var failAt: Int? }
    private let counter = Mutex(State())
    var writeAttempts: Int {
        counter.withLock { $0.attempts }
    }

    var failAtWrite: Int? {
        get { counter.withLock { $0.failAt } }
        set { counter.withLock { $0.failAt = newValue } }
    }

    func readActive() throws -> Data? {
        try base.readActive()
    }

    func readPrevious() throws -> Data? {
        try base.readPrevious()
    }

    func replaceActive(_ data: Data) throws {
        try checkpoint(); try base.replaceActive(data)
    }

    func replacePrevious(_ data: Data) throws {
        try checkpoint(); try base.replacePrevious(data)
    }

    func quarantine(_ data: Data, source: String) throws {
        try base.quarantine(data, source: source)
    }

    private func checkpoint() throws {
        try counter.withLock {
            $0.attempts += 1
            if $0.attempts == $0.failAt { throw ViewingDecisionError.unavailable }
        }
    }
}
