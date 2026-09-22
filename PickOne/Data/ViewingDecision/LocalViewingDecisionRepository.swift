import Foundation

actor LocalViewingDecisionRepository: ViewingDecisionRepository, PilotMeasurementRepository {
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
        let oldSearchIDs = Set(candidate.state.searchEvidence.map(\.id))
        if case let .search(evidence) = operation.action, evidence.id != operation.id {
            throw ViewingDecisionError.invalidData
        }
        try candidate.state.apply(operation.action, at: operation.moment)
        let evictedSearchIDs = oldSearchIDs.subtracting(candidate.state.searchEvidence.map(\.id))
        candidate.receipts.removeAll { evictedSearchIDs.contains($0.operationID) }
        let receipt = ViewingDecisionReceipt(
            operationID: operation.id,
            sessionID: candidate.state.openSession?.id,
            decisionID: candidate.state.activeDecision?.id
        )
        candidate.receipts.append(receipt)
        try candidate.validate()
        let original = candidate
        candidate.removeMeasurement(before: operation.moment.wall.addingTimeInterval(-180 * 86400))
        let pruned = original.state != candidate.state
        try commit(candidate, sanitizingPrevious: pruned)
        timingWasInterrupted = false
        return receipt
    }

    private func commit(_ candidate: ViewingDecisionEnvelope, sanitizingPrevious: Bool = false) throws {
        try candidate.validate()
        let bytes = try candidate.encoded()
        _ = try ViewingDecisionEnvelope.decode(bytes)
        try Task.checkCancellation()
        do {
            if sanitizingPrevious {
                try store.replacePrevious(bytes)
            } else if let committedBytes { try store.replacePrevious(committedBytes) }
            try store.replaceActive(bytes)
        } catch {
            // A lost lifecycle checkpoint must never turn background time into decision time.
            timingWasInterrupted = true
            throw error
        }
        // There is no suspension between persistence and publication.
        envelope = candidate
        committedBytes = bytes
    }

    func measurementSummary(at date: Date) throws -> PilotMeasurementSummary {
        var candidate = try load()
        candidate.removeMeasurement(before: date.addingTimeInterval(-180 * 86400))
        if candidate.state != envelope?.state { try commit(candidate, sanitizingPrevious: true) }
        return PilotMeasurementSummary(state: candidate.state)
    }

    func exportMeasurement(at date: Date) throws -> Data {
        try Task.checkCancellation()
        var candidate = try load()
        candidate.removeMeasurement(before: date.addingTimeInterval(-180 * 86400))
        return try candidate.measurementExport(at: date)
    }

    func deleteMeasurement(operationID: UUID, at date: Date) throws {
        try Task.checkCancellation()
        var candidate = try load()
        guard !candidate.deletionOperationIDs.contains(operationID) else { return }
        candidate.removeMeasurement(before: nil)
        candidate.id = UUID()
        candidate.deletionOperationIDs.append(operationID)
        try commit(candidate, sanitizingPrevious: true)
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
