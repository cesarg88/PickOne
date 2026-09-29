import Foundation

struct PilotSearchEvidenceDTO: Codable {
    let id: UUID
    let recordedAt: Date
    let duration: Double
    let stage: Int
    let outcome: String

    init(_ evidence: PilotSearchEvidence) {
        id = evidence.id
        recordedAt = evidence.recordedAt
        duration = evidence.duration
        stage = evidence.stage.rawValue
        outcome = switch evidence.outcome {
            case .usable: "usable"
            case .exhausted: "exhausted"
            case .retryableFailure: "retryableFailure"
        }
    }

    func domain() throws -> PilotSearchEvidence {
        guard let stage = RecommendationRecallStageKind(rawValue: stage), duration.isFinite, duration >= 0,
              recordedAt.timeIntervalSince1970.isFinite else { throw ViewingDecisionError.invalidData }
        let result: RecommendationDiagnosticOutcome
        switch outcome {
            case "usable": result = .usable
            case "exhausted": result = .exhausted
            case "retryableFailure": result = .retryableFailure
            default: throw ViewingDecisionError.invalidData
        }
        return PilotSearchEvidence(id: id, recordedAt: recordedAt, duration: duration, stage: stage, outcome: result)
    }
}

extension ViewingDecisionEnvelope {
    func validateMeasurement() throws {
        try validateCounterTotal(state.sessions.map(\.refreshCount))
        try validateCounterTotal(state.decisions.map(\.postponementCount))
        guard Set(deletionOperationIDs).count == deletionOperationIDs.count,
              state.searchEvidence.count <= 1000,
              Set(state.searchEvidence.map(\.id)).count == state.searchEvidence.count
        else {
            throw ViewingDecisionError.invalidData
        }
        for evidence in state.searchEvidence {
            _ = try PilotSearchEvidenceDTO(evidence).domain()
        }
        for session in state.sessions {
            let observed = session.observedMovieIDs ?? []
            guard Set(observed).count == observed.count, observed.allSatisfy({ $0 > 0 }),
                  Set(session.alreadyWatchedMovieIDs).count == session.alreadyWatchedMovieIDs.count,
                  Set(session.alreadyWatchedMovieIDs).isSubset(of: Set(observed))
            else {
                throw ViewingDecisionError.invalidData
            }
        }
    }

    private func validateCounterTotal(_ values: [Int]) throws {
        var total = 0
        for value in values {
            let sum = total.addingReportingOverflow(value)
            // Leave room for a reducer increment before validating the next candidate.
            guard value >= 0, !sum.overflow, sum.partialValue < Int.max else {
                throw ViewingDecisionError.invalidData
            }
            total = sum.partialValue
        }
    }

    /// Preserve complete chains needed by active work or unfinished cross-store operations.
    mutating func removeMeasurement(before cutoff: Date?) {
        let protectedDecisions = Set(state.confirmationOperations.filter { $0.stage != .completed }.map(\.decisionID))
            .union(state.decisions.filter { $0.status == .active }.map(\.id))
        let protectedSessions = Set(state.decisions.filter { protectedDecisions.contains($0.id) }
            .compactMap(\.sessionID))
        let removedSessions = Set(state.sessions.filter { session in
            guard session.status != .open, !protectedSessions.contains(session.id), let ended = session.endedAt else {
                return false
            }
            let terminalAt = state.decisions.filter { $0.sessionID == session.id }
                .reduce(ended) { max($0, $1.changedAt) }
            return cutoff.map { terminalAt <= $0 } ?? true
        }.map(\.id))
        let removedDecisions = Set(state.decisions.filter { decision in
            guard !protectedDecisions.contains(decision.id) else { return false }
            if let id = decision.sessionID { return removedSessions.contains(id) }
            return cutoff.map { decision.changedAt <= $0 } ?? true
        }.map(\.id))
        let removedSearches = Set(state.searchEvidence.filter { evidence in
            cutoff.map { evidence.recordedAt <= $0 } ?? true
        }.map(\.id))
        state.sessions.removeAll { removedSessions.contains($0.id) }
        state.decisions.removeAll { removedDecisions.contains($0.id) }
        state.confirmationOperations.removeAll { removedDecisions.contains($0.decisionID) }
        state.searchEvidence.removeAll { removedSearches.contains($0.id) }
        let retainedSearchIDs = Set(state.searchEvidence.map(\.id))
        // An undated legacy receipt may belong to any retained terminal decision.
        let canDiscardLegacyReceipt = state.sessions.isEmpty && state.decisions.isEmpty
            && state.confirmationOperations.isEmpty
        receipts.removeAll { receipt in
            let expired = receipt.recordedAt.map { date in cutoff.map { date <= $0 } ?? true }
                ?? canDiscardLegacyReceipt
            return receipt.sessionID.map(removedSessions.contains) == true
                || receipt.decisionID.map(removedDecisions.contains) == true
                || removedSearches.contains(receipt.operationID)
                || (receipt.sessionID == nil && receipt.decisionID == nil
                    && !retainedSearchIDs.contains(receipt.operationID) && expired)
        }
    }

    func measurementExport(at date: Date) throws -> Data {
        // Embed the allowlisted envelope as a JSON object, without copying display metadata.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let summary = try JSONSerialization.jsonObject(with: encoder.encode(PilotMeasurementSummary(state: state)))
        let records = try JSONSerialization.jsonObject(with: encoded())
        return try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "exportedAt": date.timeIntervalSince1970 * 1000,
            "summary": summary, "records": records,
        ], options: [.prettyPrinted, .sortedKeys])
    }
}
