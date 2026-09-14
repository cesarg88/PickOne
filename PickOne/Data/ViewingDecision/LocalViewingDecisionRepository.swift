import Foundation

actor LocalViewingDecisionRepository: ViewingDecisionRepository {
    private let store: any ViewingDecisionFileStore
    private var envelope: ViewingDecisionEnvelope?
    private var committedBytes: Data?
    private var timingWasInterrupted = false

    init(store: any ViewingDecisionFileStore) {
        self.store = store
    }

    func snapshot() throws -> ViewingDecisionState {
        try load().state
    }

    func apply(_ operation: ViewingDecisionOperation) throws -> ViewingDecisionReceipt {
        try Task.checkCancellation()
        var candidate = try load()
        if let receipt = candidate.receipts.first(where: { $0.operationID == operation.id }) { return receipt }
        if timingWasInterrupted {
            for index in candidate.state.sessions.indices where candidate.state.sessions[index].status == .open {
                candidate.state.sessions[index].timingIsReliable = false
                candidate.state.sessions[index].foregroundAnchor = nil
            }
        }
        try candidate.state.apply(operation.action, at: operation.moment)
        let receipt = ViewingDecisionReceipt(
            operationID: operation.id,
            sessionID: candidate.state.openSession?.id,
            decisionID: candidate.state.activeDecision?.id
        )
        candidate.receipts.append(receipt)
        try candidate.validate()
        let bytes = try candidate.encoded()
        _ = try ViewingDecisionEnvelope.decode(bytes)
        try Task.checkCancellation()
        do {
            if let committedBytes { try store.replacePrevious(committedBytes) }
            try store.replaceActive(bytes)
        } catch {
            // A lost lifecycle checkpoint must never turn background time into decision time.
            timingWasInterrupted = true
            throw error
        }
        // There is no suspension between persistence and publication.
        envelope = candidate
        committedBytes = bytes
        timingWasInterrupted = false
        return receipt
    }

    private func load() throws -> ViewingDecisionEnvelope {
        if let envelope { return envelope }
        let active = try store.readActive()
        if let active, let valid = try decodeOrQuarantine(active, source: "active") {
            envelope = valid
            committedBytes = active
            return valid
        }
        let previous = try store.readPrevious()
        if let previous, let valid = try decodeOrQuarantine(previous, source: "previous") {
            try store.replaceActive(previous)
            envelope = valid
            committedBytes = previous
            return valid
        }
        guard active == nil, previous == nil else { throw ViewingDecisionError.unavailable }
        let fresh = ViewingDecisionEnvelope()
        envelope = fresh
        return fresh
    }

    private func decodeOrQuarantine(_ data: Data, source: String) throws -> ViewingDecisionEnvelope? {
        do { return try ViewingDecisionEnvelope.decode(data) } catch {
            try store.quarantine(data, source: source)
            return nil
        }
    }
}
