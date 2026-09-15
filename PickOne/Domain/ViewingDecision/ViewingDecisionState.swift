import Foundation

struct ViewingDecisionState: Equatable, Sendable {
    var sessions: [RecommendationSession] = []
    var decisions: [ViewingDecision] = []
    // Runtime evidence is deliberately not restored as proof of foreground activity.
    var isActive = false
    var visibleSurface: ViewingDecisionSurface?
    var lastMoment: DecisionMoment?
    var lastDecisionMoment: DecisionMoment?

    var activeDecision: ViewingDecision? {
        decisions.last { $0.status == .active }
    }

    var openSession: RecommendationSession? {
        sessions.last { $0.status == .open }
    }

    mutating func apply(_ action: ViewingDecisionAction, at moment: DecisionMoment) throws {
        guard moment.wall.timeIntervalSince1970.isFinite, moment.monotonicSeconds.isFinite,
              moment.monotonicSeconds >= 0
        else {
            throw ViewingDecisionError.invalidData
        }
        if case let .pick(selection, snapshot, _) = action,
           !snapshot.recommendations.contains(selection)
        { throw ViewingDecisionError.invalidRecommendation }
        if case let .cancel(id) = action, activeDecision?.id != id {
            throw ViewingDecisionError.staleDecision
        }
        let ordered = lastMoment
            .map { $0.runtimeID == moment.runtimeID && $0.monotonicSeconds <= moment.monotonicSeconds } ?? true
        if !ordered {
            switch action {
                case .pick, .cancel: break
                default: return
            }
        }
        switch action {
            case .pick, .cancel:
                if let previous = lastDecisionMoment, previous.runtimeID == moment.runtimeID,
                   previous.monotonicSeconds > moment.monotonicSeconds { throw ViewingDecisionError.staleDecision }
            default: break
        }
        if ordered { advance(to: moment) }
        switch action {
            case let .activate(surface):
                isActive = true
                visibleSurface = surface
                if let surface { observe(surface, at: moment) }
            case .pause:
                isActive = false
                setAnchor(nil)
            case let .observe(surface):
                visibleSurface = surface
                if isActive { observe(surface, at: moment) }
            case .leaveSurface:
                visibleSurface = nil
            case let .refresh(surface):
                if isActive, visibleSurface == surface {
                    observe(surface, at: moment)
                    if let index = openIndex { sessions[index].refreshCount += 1 }
                }
            case let .pick(selection, snapshot, isVisible):
                let trusted = ordered && isActive && isVisible
                    && (visibleSurface == nil || visibleSurface == snapshot)
                    && (openSession.map { moment.wall >= $0.startedAt } ?? true)
                if trusted { observe(snapshot, at: moment) }
                pick(selection, at: moment, trusted: trusted)
            case let .cancel(id):
                if let index = decisions.firstIndex(where: { $0.id == id }) {
                    decisions[index].status = .cancelled
                    decisions[index].changedAt = max(decisions[index].changedAt, moment.wall)
                    lastDecisionMoment = moment
                    if let sessionIndex = openIndex {
                        sessions[sessionIndex].finalDecisionID = nil
                        sessions[sessionIndex].lastActivityAt = max(sessions[sessionIndex].lastActivityAt, moment.wall)
                    }
                }
            case .expire:
                break
        }
        if ordered { lastMoment = moment }
    }

    private var openIndex: Int? {
        sessions.lastIndex { $0.status == .open }
    }

    private mutating func advance(to moment: DecisionMoment) {
        guard let index = openIndex else { return }
        let deadline = sessions[index].lastActivityAt.addingTimeInterval(30 * 60)
        let ended = moment.wall >= deadline
        if let anchor = sessions[index].foregroundAnchor {
            if anchor.runtimeID == moment.runtimeID, moment.monotonicSeconds >= anchor.monotonicSeconds,
               moment.wall >= anchor.wall
            {
                let delta = moment.monotonicSeconds - anchor.monotonicSeconds
                let interval = ended ? min(delta, max(0, deadline.timeIntervalSince(anchor.wall))) : delta
                sessions[index].foregroundDuration += interval
            } else {
                sessions[index].timingIsReliable = false
            }
        }
        if ended {
            sessions[index].endedAt = deadline
            sessions[index].status = sessions[index].finalDecisionID == nil ? .abandoned : .decided
            sessions[index].foregroundAnchor = nil
        } else {
            sessions[index].foregroundAnchor = isActive ? moment : nil
        }
    }

    private mutating func observe(_ surface: ViewingDecisionSurface, at moment: DecisionMoment) {
        if openIndex == nil {
            sessions.append(RecommendationSession(
                id: DecisionSessionID(), startedAt: moment.wall, lastActivityAt: moment.wall
            ))
        }
        guard let index = openIndex, let setID = surface.recommendations.first?.setID else { return }
        sessions[index].lastActivityAt = max(sessions[index].lastActivityAt, moment.wall)
        if !sessions[index].observedSetIDs.contains(setID) {
            sessions[index].observedSetIDs.append(setID)
        }
        setAnchor(moment)
    }

    private mutating func setAnchor(_ moment: DecisionMoment?) {
        guard let index = openIndex else { return }
        sessions[index].foregroundAnchor = moment
    }

    private mutating func pick(_ selection: PickRecommendation, at moment: DecisionMoment, trusted: Bool) {
        let sessionIndex = trusted ? openIndex : nil
        let timing: DecisionTiming = if let sessionIndex, sessions[sessionIndex].timingIsReliable {
            .available(sessions[sessionIndex].foregroundDuration)
        } else { .unavailable }
        for index in decisions.indices where decisions[index].status == .active {
            decisions[index].status = .superseded
            decisions[index].changedAt = max(decisions[index].changedAt, moment.wall)
            if let openIndex, sessions[openIndex].finalDecisionID == decisions[index].id {
                sessions[openIndex].finalDecisionID = nil
            }
        }
        let decision = ViewingDecision(
            id: ViewingDecisionID(), sessionID: sessionIndex.map { sessions[$0].id },
            recommendation: selection, pickedAt: moment.wall, timing: timing, changedAt: moment.wall
        )
        decisions.append(decision)
        lastDecisionMoment = moment
        if let sessionIndex {
            if sessions[sessionIndex].firstPickTiming == nil { sessions[sessionIndex].firstPickTiming = timing }
            sessions[sessionIndex].finalDecisionID = decision.id
        }
    }
}
