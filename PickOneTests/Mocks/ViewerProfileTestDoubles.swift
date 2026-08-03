import Foundation
@testable import PickOne
import Synchronization

final class InMemoryViewerProfileDataStore: ViewerProfileDataStore {
    private struct State: Sendable {
        var data: Data?
        var rejectReads = false
        var rejectReplacements = false
        var replacementCount = 0
        var removalCount = 0
    }

    private let state: Mutex<State>

    init(data: Data? = nil) {
        state = Mutex(State(data: data))
    }

    var data: Data? {
        state.withLock { $0.data }
    }

    var replacementCount: Int {
        state.withLock { $0.replacementCount }
    }

    func setRejectReads(_ value: Bool) {
        state.withLock { $0.rejectReads = value }
    }

    func setRejectReplacements(_ value: Bool) {
        state.withLock { $0.rejectReplacements = value }
    }

    func read() throws -> Data? {
        try state.withLock { state in
            if state.rejectReads {
                throw TestViewerProfileStoreError.rejected
            }
            return state.data
        }
    }

    func replace(with data: Data) throws {
        try state.withLock { state in
            if state.rejectReplacements {
                throw TestViewerProfileStoreError.rejected
            }
            state.data = data
            state.replacementCount += 1
        }
    }

    func remove() throws {
        state.withLock { state in
            state.data = nil
            state.removalCount += 1
        }
    }
}

enum TestViewerProfileStoreError: Error {
    case rejected
}

struct FailingViewerProfileEncoder: ViewerProfileEnvelopeCoding {
    private let decoder = JSONViewerProfileEnvelopeCoder()

    func decodeEnvelope(from data: Data) throws -> ViewerStateEnvelopeV1DTO {
        try decoder.decodeEnvelope(from: data)
    }

    func encodeEnvelope(_ envelope: ViewerStateEnvelopeV1DTO) throws -> Data {
        throw TestViewerProfileStoreError.rejected
    }
}
