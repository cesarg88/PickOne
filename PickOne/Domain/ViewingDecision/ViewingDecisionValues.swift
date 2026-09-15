import Foundation

struct DecisionSessionID: Hashable, Sendable {
    let rawValue: UUID
    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct ViewingDecisionID: Hashable, Sendable {
    let rawValue: UUID
    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct DecisionMoment: Equatable, Sendable {
    let wall: Date
    let monotonicSeconds: TimeInterval
    let runtimeID: UUID
}

enum DecisionTiming: Equatable, Sendable {
    case available(TimeInterval)
    case unavailable
}

struct PickRecommendation: Equatable, Sendable {
    let movieID: Int
    let setID: UUID
    let cycleID: UUID
    let role: DecisionRole
}

struct ViewingDecisionSurface: Equatable, Sendable {
    let recommendations: [PickRecommendation]

    init(recommendations: [PickRecommendation]) throws {
        guard let first = recommendations.first,
              recommendations.allSatisfy({ $0.movieID > 0 && $0.setID == first.setID && $0.cycleID == first.cycleID }),
              Set(recommendations.map(\.movieID)).count == recommendations.count
        else { throw ViewingDecisionError.invalidRecommendation }
        self.recommendations = recommendations
    }
}

struct RecommendationSession: Equatable, Sendable {
    enum Status: String, Sendable { case open, abandoned, decided }
    let id: DecisionSessionID
    let startedAt: Date
    var lastActivityAt: Date
    var endedAt: Date?
    var status: Status = .open
    var foregroundDuration: TimeInterval = 0
    var timingIsReliable = true
    var foregroundAnchor: DecisionMoment?
    var observedSetIDs: [UUID] = []
    var refreshCount = 0
    var firstPickTiming: DecisionTiming?
    var finalDecisionID: ViewingDecisionID?
}

struct ViewingDecision: Equatable, Sendable {
    enum Status: String, Sendable { case active, superseded, cancelled }
    let id: ViewingDecisionID
    let sessionID: DecisionSessionID?
    let recommendation: PickRecommendation
    let pickedAt: Date
    let timing: DecisionTiming
    var changedAt: Date
    var status: Status = .active
}

enum ViewingDecisionAction: Equatable, Sendable {
    case activate(ViewingDecisionSurface?)
    case pause
    case observe(ViewingDecisionSurface)
    case leaveSurface
    case refresh(ViewingDecisionSurface)
    case pick(PickRecommendation, snapshot: ViewingDecisionSurface, isVisible: Bool)
    case cancel(ViewingDecisionID)
    case expire
}

struct ViewingDecisionOperation: Equatable, Sendable {
    let id: UUID
    let action: ViewingDecisionAction
    let moment: DecisionMoment
    init(id: UUID = UUID(), action: ViewingDecisionAction, moment: DecisionMoment) {
        self.id = id
        self.action = action
        self.moment = moment
    }
}

struct ViewingDecisionReceipt: Equatable, Sendable {
    let operationID: UUID
    let sessionID: DecisionSessionID?
    let decisionID: ViewingDecisionID?
}

enum ViewingDecisionError: Error, Equatable, Sendable {
    case invalidRecommendation, invalidData, unsupportedSchema, unavailable, staleDecision
}

protocol ViewingDecisionRepository: Sendable {
    func snapshot() async throws -> ViewingDecisionState
    func apply(_ operation: ViewingDecisionOperation) async throws -> ViewingDecisionReceipt
}

struct ManageViewingDecision: Sendable {
    let repository: any ViewingDecisionRepository
    func snapshot() async throws -> ViewingDecisionState {
        try await repository.snapshot()
    }

    func apply(_ operation: ViewingDecisionOperation) async throws -> ViewingDecisionReceipt {
        try await repository.apply(operation)
    }
}
