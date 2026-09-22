import Foundation

struct ViewingDecisionEnvelope: Sendable {
    var id = UUID()
    var state = ViewingDecisionState()
    var receipts: [ViewingDecisionReceipt] = []

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(ViewingDecisionEnvelopeDTO(self))
    }

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let header = try decoder.decode(ViewingDecisionHeaderDTO.self, from: data)
        guard [1, 2].contains(header.schemaVersion) else { throw ViewingDecisionError.unsupportedSchema }
        let result = try decoder.decode(ViewingDecisionEnvelopeDTO.self, from: data).domain()
        if header.schemaVersion == 1 {
            guard result.state.confirmationOperations.isEmpty,
                  result.state.decisions.allSatisfy({
                      $0.postponementCount == 0 && $0.nextConfirmationAt == nil
                          && $0.confirmedAt == nil && $0.satisfaction == nil
                  }) else { throw ViewingDecisionError.invalidData }
        }
        try result.validate()
        return result
    }

    func validate() throws {
        let sessions = state.sessions
        let decisions = state.decisions
        guard Set(sessions.map(\.id)).count == sessions.count,
              Set(decisions.map(\.id)).count == decisions.count,
              Set(receipts.map(\.operationID)).count == receipts.count,
              sessions.count(where: { $0.status == .open }) <= 1,
              decisions.count(where: { $0.status == .active }) <= 1
        else { throw ViewingDecisionError.invalidData }
        for session in sessions {
            guard session.foregroundDuration.isFinite, session.foregroundDuration >= 0,
                  session.lastActivityAt >= session.startedAt, session.refreshCount >= 0,
                  Set(session.observedSetIDs).count == session.observedSetIDs.count,
                  !session.observedSetIDs.isEmpty,
                  (session.status == .open) == (session.endedAt == nil),
                  session.endedAt.map({ $0 >= session.lastActivityAt }) ?? true,
                  session.status != .decided || session.finalDecisionID != nil,
                  session.status != .abandoned || session.finalDecisionID == nil
            else { throw ViewingDecisionError.invalidData }
            if session.status == .open {
                let activeID = decisions.first { $0.status == .active && $0.sessionID == session.id }?.id
                guard session.finalDecisionID == activeID else { throw ViewingDecisionError.invalidData }
            }
            if let id = session.finalDecisionID {
                guard decisions.contains(where: { $0.id == id && $0.sessionID == session.id }) else {
                    throw ViewingDecisionError.invalidData
                }
            }
        }
        for decision in decisions {
            guard decision.recommendation.movieID > 0,
                  decision.changedAt >= decision.pickedAt else { throw ViewingDecisionError.invalidData }
            if let id = decision.sessionID {
                guard let session = sessions.first(where: { $0.id == id }),
                      session.observedSetIDs.contains(decision.recommendation.setID),
                      decision.pickedAt >= session.startedAt
                else { throw ViewingDecisionError.invalidData }
            } else if decision.timing != .unavailable { throw ViewingDecisionError.invalidData }
        }
        try validateConfirmations()
        for receipt in receipts {
            guard receipt.sessionID.map({ id in sessions.contains { $0.id == id } }) ?? true,
                  receipt.decisionID.map({ id in decisions.contains { $0.id == id } }) ?? true
            else { throw ViewingDecisionError.invalidData }
        }
    }
}

private struct ViewingDecisionHeaderDTO: Decodable { let schemaVersion: Int }

private struct ViewingDecisionEnvelopeDTO: Codable {
    let schemaVersion: Int
    let id: UUID
    let sessions: [RecommendationSessionDTO]
    let decisions: [ViewingDecisionDTO]
    let receipts: [ViewingDecisionReceiptDTO]
    let lastDecisionMoment: DecisionMomentDTO?
    let confirmationOperations: [ViewingConfirmationOperationDTO]?

    init(_ envelope: ViewingDecisionEnvelope) {
        schemaVersion = 2
        confirmationOperations = envelope.state.confirmationOperations.map(ViewingConfirmationOperationDTO.init)
        id = envelope.id
        sessions = envelope.state.sessions.map(RecommendationSessionDTO.init)
        decisions = envelope.state.decisions.map(ViewingDecisionDTO.init)
        receipts = envelope.receipts.map(ViewingDecisionReceiptDTO.init)
        lastDecisionMoment = envelope.state.lastDecisionMoment.map(DecisionMomentDTO.init)
    }

    func domain() throws -> ViewingDecisionEnvelope {
        try ViewingDecisionEnvelope(
            id: id,
            state: ViewingDecisionState(
                sessions: sessions.map { try $0.domain() },
                decisions: decisions.map { try $0.domain() },
                confirmationOperations: (confirmationOperations ?? []).map { try $0.domain() },
                lastDecisionMoment: lastDecisionMoment?.domain()
            ),
            receipts: receipts.map { $0.domain() }
        )
    }
}

private struct DecisionTimingDTO: Codable {
    let seconds: Double?
    init(_ timing: DecisionTiming) {
        if case let .available(seconds) = timing { self.seconds = seconds } else { seconds = nil }
    }

    func domain() throws -> DecisionTiming {
        guard let seconds else { return .unavailable }
        guard seconds.isFinite, seconds >= 0 else { throw ViewingDecisionError.invalidData }
        return .available(seconds)
    }
}

private struct RecommendationSessionDTO: Codable {
    let id: UUID
    let startedAt: Date
    let lastActivityAt: Date
    let endedAt: Date?
    let status: String
    let foregroundDuration: Double
    let timingIsReliable: Bool
    let foregroundAnchor: DecisionMomentDTO?
    let observedSetIDs: [UUID]
    let refreshCount: Int
    let firstPickTiming: DecisionTimingDTO?
    let finalDecisionID: UUID?

    init(_ session: RecommendationSession) {
        id = session.id.rawValue
        startedAt = session.startedAt
        lastActivityAt = session.lastActivityAt
        endedAt = session.endedAt
        status = session.status.rawValue
        foregroundDuration = session.foregroundDuration
        timingIsReliable = session.timingIsReliable
        foregroundAnchor = session.foregroundAnchor.map(DecisionMomentDTO.init)
        observedSetIDs = session.observedSetIDs
        refreshCount = session.refreshCount
        firstPickTiming = session.firstPickTiming.map(DecisionTimingDTO.init)
        finalDecisionID = session.finalDecisionID?.rawValue
    }

    func domain() throws -> RecommendationSession {
        guard let status = RecommendationSession.Status(rawValue: status)
        else { throw ViewingDecisionError.invalidData }
        return try RecommendationSession(
            id: DecisionSessionID(rawValue: id), startedAt: startedAt, lastActivityAt: lastActivityAt,
            endedAt: endedAt, status: status, foregroundDuration: foregroundDuration,
            timingIsReliable: timingIsReliable, foregroundAnchor: foregroundAnchor?.domain(),
            observedSetIDs: observedSetIDs, refreshCount: refreshCount,
            firstPickTiming: firstPickTiming?.domain(), finalDecisionID: finalDecisionID.map(ViewingDecisionID.init)
        )
    }
}

private struct DecisionMomentDTO: Codable {
    let wall: Date
    let monotonicSeconds: Double
    let runtimeID: UUID
    init(_ moment: DecisionMoment) {
        wall = moment.wall; monotonicSeconds = moment.monotonicSeconds; runtimeID = moment.runtimeID
    }

    func domain() throws -> DecisionMoment {
        guard monotonicSeconds.isFinite, monotonicSeconds >= 0 else { throw ViewingDecisionError.invalidData }
        return DecisionMoment(wall: wall, monotonicSeconds: monotonicSeconds, runtimeID: runtimeID)
    }
}

private struct ViewingDecisionDTO: Codable {
    let id: UUID
    let sessionID: UUID?
    let movieID: Int
    let setID: UUID
    let cycleID: UUID
    let role: String
    let pickedAt: Date
    let changedAt: Date
    let timing: DecisionTimingDTO
    let status: String
    let postponementCount: Int?
    let nextConfirmationAt: Date?
    let confirmedAt: Date?
    let satisfaction: String?

    init(_ decision: ViewingDecision) {
        postponementCount = decision.postponementCount
        nextConfirmationAt = decision.nextConfirmationAt
        confirmedAt = decision.confirmedAt
        satisfaction = decision.satisfaction?.rawValue
        id = decision.id.rawValue
        sessionID = decision.sessionID?.rawValue
        movieID = decision.recommendation.movieID
        setID = decision.recommendation.setID
        cycleID = decision.recommendation.cycleID
        role = switch decision.recommendation.role {
            case .safeChoice: "safeChoice"
            case .stretchChoice: "stretchChoice"
            case .discoveryChoice: "discoveryChoice"
        }
        pickedAt = decision.pickedAt
        changedAt = decision.changedAt
        timing = DecisionTimingDTO(decision.timing)
        status = decision.status.rawValue
    }

    func domain() throws -> ViewingDecision {
        let decisionRole: DecisionRole
        switch role {
            case "safeChoice": decisionRole = .safeChoice
            case "stretchChoice": decisionRole = .stretchChoice
            case "discoveryChoice": decisionRole = .discoveryChoice
            default: throw ViewingDecisionError.invalidData
        }
        guard let status = ViewingDecision.Status(rawValue: status) else { throw ViewingDecisionError.invalidData }
        return try ViewingDecision(
            id: ViewingDecisionID(rawValue: id), sessionID: sessionID.map(DecisionSessionID.init),
            recommendation: PickRecommendation(movieID: movieID, setID: setID, cycleID: cycleID, role: decisionRole),
            pickedAt: pickedAt, timing: timing.domain(), changedAt: changedAt, status: status,
            postponementCount: postponementCount ?? 0, nextConfirmationAt: nextConfirmationAt,
            confirmedAt: confirmedAt, satisfaction: satisfaction.map { value in
                guard let reaction = MovieReaction(rawValue: value)
                else { throw ViewingDecisionError.invalidData }; return reaction
            }
        )
    }
}

private struct ViewingDecisionReceiptDTO: Codable {
    let operationID: UUID
    let sessionID: UUID?
    let decisionID: UUID?
    init(_ receipt: ViewingDecisionReceipt) {
        operationID = receipt.operationID
        sessionID = receipt.sessionID?.rawValue
        decisionID = receipt.decisionID?.rawValue
    }

    func domain() -> ViewingDecisionReceipt {
        ViewingDecisionReceipt(
            operationID: operationID,
            sessionID: sessionID.map(DecisionSessionID.init),
            decisionID: decisionID.map(ViewingDecisionID.init)
        )
    }
}
