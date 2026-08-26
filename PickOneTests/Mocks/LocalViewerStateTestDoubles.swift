import Foundation
@testable import PickOne
import Synchronization

final class InMemoryLocalViewerStateFileStore: LocalViewerStateFileStore {
    private struct State: Sendable {
        var activeData: Data?
        var previousData: Data?
        var quarantinedItems: [LocalViewerStateQuarantineItem] = []
        var activeReplacementCount = 0
        var previousReplacementCount = 0
        var rejectActiveRead = false
        var rejectPreviousRead = false
        var rejectActiveReplacement = false
        var rejectPreviousReplacement = false
        var rejectPreviousRemoval = false
        var rejectQuarantine = false
    }

    private let state: Mutex<State>

    init(activeData: Data? = nil, previousData: Data? = nil) {
        state = Mutex(State(activeData: activeData, previousData: previousData))
    }

    var activeData: Data? {
        state.withLock { $0.activeData }
    }

    var previousData: Data? {
        state.withLock { $0.previousData }
    }

    var quarantinedItems: [LocalViewerStateQuarantineItem] {
        state.withLock { $0.quarantinedItems }
    }

    var activeReplacementCount: Int {
        state.withLock { $0.activeReplacementCount }
    }

    var previousReplacementCount: Int {
        state.withLock { $0.previousReplacementCount }
    }

    var rejectActiveRead: Bool {
        get { state.withLock { $0.rejectActiveRead } }
        set { state.withLock { $0.rejectActiveRead = newValue } }
    }

    var rejectPreviousRead: Bool {
        get { state.withLock { $0.rejectPreviousRead } }
        set { state.withLock { $0.rejectPreviousRead = newValue } }
    }

    var rejectActiveReplacement: Bool {
        get { state.withLock { $0.rejectActiveReplacement } }
        set { state.withLock { $0.rejectActiveReplacement = newValue } }
    }

    var rejectPreviousReplacement: Bool {
        get { state.withLock { $0.rejectPreviousReplacement } }
        set { state.withLock { $0.rejectPreviousReplacement = newValue } }
    }

    var rejectPreviousRemoval: Bool {
        get { state.withLock { $0.rejectPreviousRemoval } }
        set { state.withLock { $0.rejectPreviousRemoval = newValue } }
    }

    var rejectQuarantine: Bool {
        get { state.withLock { $0.rejectQuarantine } }
        set { state.withLock { $0.rejectQuarantine = newValue } }
    }

    func readActive() throws -> Data? {
        try state.withLock {
            if $0.rejectActiveRead { throw LocalViewerStateTestError.rejected }
            return $0.activeData
        }
    }

    func readPrevious() throws -> Data? {
        try state.withLock {
            if $0.rejectPreviousRead { throw LocalViewerStateTestError.rejected }
            return $0.previousData
        }
    }

    func replaceActive(with data: Data) throws {
        try state.withLock {
            if $0.rejectActiveReplacement { throw LocalViewerStateTestError.rejected }
            $0.activeData = data
            $0.activeReplacementCount += 1
        }
    }

    func replacePrevious(with data: Data) throws {
        try state.withLock {
            if $0.rejectPreviousReplacement { throw LocalViewerStateTestError.rejected }
            $0.previousData = data
            $0.previousReplacementCount += 1
        }
    }

    func removePrevious() throws {
        try state.withLock {
            if $0.rejectPreviousRemoval { throw LocalViewerStateTestError.rejected }
            $0.previousData = nil
        }
    }

    func quarantine(_ data: Data, source: LocalViewerStateQuarantineSource) throws {
        try state.withLock {
            if $0.rejectQuarantine { throw LocalViewerStateTestError.rejected }
            $0.quarantinedItems.append(
                LocalViewerStateQuarantineItem(source: source, data: data)
            )
        }
    }
}

final class InMemoryLegacyViewerStateSource: LegacyViewerStateSource {
    private struct State: Sendable {
        var profileData: Data?
        var watchlistData: Data?
        var rejectReads = false
    }

    private let state: Mutex<State>

    init(profileData: Data? = nil, watchlistData: Data? = nil) {
        state = Mutex(State(profileData: profileData, watchlistData: watchlistData))
    }

    var rejectReads: Bool {
        get { state.withLock { $0.rejectReads } }
        set { state.withLock { $0.rejectReads = newValue } }
    }

    func readProfile() throws -> Data? {
        try state.withLock {
            if $0.rejectReads { throw LocalViewerStateTestError.rejected }
            return $0.profileData
        }
    }

    func readWatchlist() throws -> Data? {
        try state.withLock {
            if $0.rejectReads { throw LocalViewerStateTestError.rejected }
            return $0.watchlistData
        }
    }
}

final class SequenceUUIDGenerator: Sendable {
    private let values: Mutex<[UUID]>

    init(_ values: [UUID]) {
        self.values = Mutex(values)
    }

    func next() -> UUID {
        values.withLock { values in
            guard !values.isEmpty else { return UUID() }
            return values.removeFirst()
        }
    }
}

enum LocalViewerStateTestError: Error {
    case rejected
}

struct FailingLocalViewerStateEncoder: LocalViewerStateEnvelopeCoding {
    func decode(_ data: Data) throws -> LocalViewerStateEnvelopeV2DTO {
        try JSONLocalViewerStateEnvelopeCoder().decode(data)
    }

    func encode(_ envelope: LocalViewerStateEnvelopeV2DTO) throws -> Data {
        throw LocalViewerStateTestError.rejected
    }
}
