import Foundation
@testable import PickOne
import Synchronization
import Testing

struct ViewingDecisionPersistenceTests {
    @Test func duplicatePickRefreshAndCancelSurviveRecreation() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        _ = try await repository.apply(operation(.activate(surface), 0))
        let refresh = operation(.refresh(surface), 10)
        let refreshReceipt = try await repository.apply(refresh)
        #expect(try await repository.apply(refresh) == refreshReceipt)
        let pick = operation(.pick(selection, snapshot: surface, isVisible: true), 20)
        let receipt = try await repository.apply(pick)
        let reopened = LocalViewingDecisionRepository(store: store)
        #expect(try await reopened.apply(pick) == receipt)
        let snapshot = try await reopened.snapshot()
        #expect(snapshot.decisions.count == 1)
        #expect(snapshot.sessions.first?.refreshCount == 1)
        let id = try #require(snapshot.activeDecision?.id)
        let cancel = operation(.cancel(id), 30)
        let cancellation = try await reopened.apply(cancel)
        let finalRepository = LocalViewingDecisionRepository(store: store)
        #expect(try await finalRepository.apply(cancel) == cancellation)
        #expect(try await finalRepository.snapshot().activeDecision == nil)
        #expect(try await finalRepository.snapshot().decisions.first?.status == .cancelled)
    }

    @Test(arguments: ["active", "previous"])
    func failedWriteKeepsPriorEnvelopeAndRetrySucceeds(boundary: String) async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        _ = try await repository.apply(operation(.activate(surface), 0))
        let before = store.active
        store.failure = boundary
        let selection = try #require(surface.recommendations.first)
        let pick = operation(.pick(selection, snapshot: surface, isVisible: true), 10)
        await #expect(throws: ViewingDecisionError.unavailable) { try await repository.apply(pick) }
        #expect(store.active == before)
        #expect(try await repository.snapshot().activeDecision == nil)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().activeDecision == nil)
        store.failure = nil
        _ = try await repository.apply(pick)
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().activeDecision?
            .recommendation == selection)
    }

    @Test(arguments: [Data("broken".utf8), Data("{\"schemaVersion\":99}".utf8)])
    func exactInvalidBytesAreQuarantinedAndPreviousRecovered(bytes: Data) async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        _ = try await repository.apply(operation(.activate(surface), 0))
        let selection = try #require(surface.recommendations.first)
        _ = try await repository.apply(operation(.pick(selection, snapshot: surface, isVisible: true), 10))
        let pickedBytes = store.active
        _ = try await repository.apply(operation(.pause, 20))
        store.active = bytes
        let recovered = try await LocalViewingDecisionRepository(store: store).snapshot()
        #expect(recovered.activeDecision?.recommendation == selection)
        #expect(store.quarantined.contains(bytes))
        #expect(store.active == pickedBytes)
    }

    @Test func failedRecoveryNeverFabricatesEmptyHistory() async throws {
        let store = MemoryViewingDecisionStore()
        store.active = Data("broken".utf8)
        store.previous = Data("also broken".utf8)
        let repository = LocalViewingDecisionRepository(store: store)
        await #expect(throws: ViewingDecisionError.unavailable) { try await repository.snapshot() }
        await #expect(throws: ViewingDecisionError.unavailable) {
            try await LocalViewingDecisionRepository(store: store).snapshot()
        }
        #expect(store.active == Data("broken".utf8))
        #expect(store.previous == Data("also broken".utf8))
    }

    @Test(arguments: ["read", "quarantine"])
    func storageFailureDoesNotOverwriteUnreadHistory(boundary: String) async throws {
        let store = MemoryViewingDecisionStore()
        store.active = Data("broken".utf8)
        store.failure = boundary
        await #expect(throws: ViewingDecisionError.unavailable) {
            try await LocalViewingDecisionRepository(store: store).snapshot()
        }
        #expect(store.active == Data("broken".utf8))
    }

    @Test func interruptedForegroundUsesUnavailableButCleanPauseRetainsTiming() async throws {
        for paused in [false, true] {
            let store = MemoryViewingDecisionStore()
            let repository = LocalViewingDecisionRepository(store: store)
            let surface = try ViewingDecisionTestFixtures.surface()
            _ = try await repository.apply(operation(.activate(surface), 0))
            if paused { _ = try await repository.apply(operation(.pause, 10)) }
            let reopened = LocalViewingDecisionRepository(store: store)
            let runtimeID = UUID()
            _ = try await reopened.apply(ViewingDecisionOperation(
                action: .activate(surface),
                moment: ViewingDecisionTestFixtures.moment(100, runtimeID: runtimeID)
            ))
            let selection = try #require(surface.recommendations.first)
            _ = try await reopened.apply(ViewingDecisionOperation(
                action: .pick(selection, snapshot: surface, isVisible: true),
                moment: ViewingDecisionTestFixtures.moment(110, runtimeID: runtimeID)
            ))
            #expect(try await reopened.snapshot().activeDecision?.timing == (paused ? .available(20) : .unavailable))
        }
    }

    @Test func simultaneousDuplicateOperationsCommitOnce() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        let pick = operation(.pick(selection, snapshot: surface, isVisible: false), 10)
        let receipts = try await withThrowingTaskGroup(of: ViewingDecisionReceipt.self) { group in
            for _ in 0 ..< 20 {
                group.addTask { try await repository.apply(pick) }
            }
            var receipts: [ViewingDecisionReceipt] = []
            for try await receipt in group {
                receipts.append(receipt)
            }
            return receipts
        }
        #expect(receipts.allSatisfy { $0 == receipts.first })
        #expect(try await repository.snapshot().decisions.count == 1)
        #expect(store.writes == 1)
    }

    @Test(arguments: ["Plain", "Application Support", "Selección % piloto"])
    func applicationSupportRoundTripStoresOnlyAllowedEvidence(directoryName: String) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let directory = root.appending(path: directoryName, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ApplicationSupportViewingDecisionStore(directory: directory)
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        _ = try await repository.apply(operation(.activate(surface), 0))
        let selection = try #require(surface.recommendations.first)
        _ = try await repository.apply(operation(.pick(selection, snapshot: surface, isVisible: true), 15))
        #expect(try await LocalViewingDecisionRepository(store: store).snapshot().activeDecision?
            .recommendation == selection)
        let bytes = try #require(try store.readActive())
        let text = try #require(String(data: bytes, encoding: .utf8))
        for forbidden in [
            "title",
            "poster",
            "provider",
            "prompt",
            "query",
            "token",
            "watched",
            "reaction",
            "provenance",
        ] {
            #expect(!text.localizedCaseInsensitiveContains(forbidden))
        }
        #expect(try store.readPrevious() != nil)
    }

    @Test func failedBackgroundWriteNeverCountsBackgroundAsForeground() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        _ = try await repository.apply(operation(.activate(surface), 0))
        store.failure = "active"
        await #expect(throws: ViewingDecisionError.unavailable) { try await repository.apply(operation(.pause, 10)) }
        store.failure = nil
        _ = try await repository.apply(operation(.activate(surface), 110))
        let selection = try #require(surface.recommendations.first)
        _ = try await repository.apply(operation(.pick(selection, snapshot: surface, isVisible: true), 120))
        #expect(try await repository.snapshot().activeDecision?.timing == .unavailable)
    }

    @Test func cancellationBeforeMutationWritesNothing() async throws {
        let store = MemoryViewingDecisionStore()
        let repository = LocalViewingDecisionRepository(store: store)
        let surface = try ViewingDecisionTestFixtures.surface()
        let selection = try #require(surface.recommendations.first)
        let pick = operation(.pick(selection, snapshot: surface, isVisible: false), 0)
        let task = Task {
            while !Task.isCancelled {
                await Task.yield()
            }
            return try await repository.apply(pick)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(store.active == nil)
        #expect(try await repository.snapshot().decisions.isEmpty)
    }

    private func operation(_ action: ViewingDecisionAction, _ seconds: Double) -> ViewingDecisionOperation {
        ViewingDecisionOperation(action: action, moment: ViewingDecisionTestFixtures.moment(seconds))
    }
}

final class MemoryViewingDecisionStore: ViewingDecisionFileStore {
    private struct State: Sendable {
        var active: Data?
        var previous: Data?
        var quarantined: [Data] = []
        var failure: String?
        var writes = 0
    }

    private let state = Mutex(State())
    var active: Data? {
        get { state.withLock { $0.active } } set { state.withLock { $0.active = newValue } }
    }

    var previous: Data? {
        get { state.withLock { $0.previous } } set { state.withLock { $0.previous = newValue } }
    }

    var failure: String? {
        get { state.withLock { $0.failure } } set { state.withLock { $0.failure = newValue } }
    }

    var quarantined: [Data] {
        state.withLock { $0.quarantined }
    }

    var writes: Int {
        state.withLock { $0.writes }
    }

    func readActive() throws -> Data? {
        if failure == "read" { throw ViewingDecisionError.unavailable }; return active
    }

    func readPrevious() throws -> Data? {
        previous
    }

    func replaceActive(_ data: Data) throws {
        try state.withLock {
            if $0.failure == "active" { throw ViewingDecisionError.unavailable }
            $0.active = data
            $0.writes += 1
        }
    }

    func replacePrevious(_ data: Data) throws {
        try state.withLock {
            if $0.failure == "previous" { throw ViewingDecisionError.unavailable }
            $0.previous = data
        }
    }

    func quarantine(_ data: Data, source _: String) throws {
        try state.withLock {
            if $0.failure == "quarantine" { throw ViewingDecisionError.unavailable }
            $0.quarantined.append(data)
        }
    }
}
