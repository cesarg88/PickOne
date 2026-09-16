import Foundation

struct ViewingConfirmationOperation: Equatable, Sendable {
    enum Stage: String, Sendable { case prepared, applyingViewerMovieState, viewerMovieStateCommitted, completed }
    let id: UUID
    let decisionID: ViewingDecisionID
    let movieID: Int
    let createdAt: Date
    let reaction: MovieReaction?
    var stage: Stage = .prepared
}

enum ViewingConfirmationCommand: Equatable, Sendable {
    case notYet(ViewingDecisionID)
    case notWatched(ViewingDecisionID)
    case prepare(ViewingConfirmationOperation)
    case advance(UUID, ViewingConfirmationOperation.Stage)
}

extension ViewingDecision {
    func isAutomaticallyEligible(at date: Date) -> Bool {
        status == .active && postponementCount < 3 && date >= confirmationEligibleAt
    }

    var confirmationEligibleAt: Date {
        nextConfirmationAt ?? pickedAt.addingTimeInterval(12 * 3600)
    }
}

extension ViewingDecisionState {
    var manualConfirmations: [ViewingDecision] {
        decisions.filter { $0.status == .active && $0.postponementCount >= 3 }
    }

    mutating func confirm(_ command: ViewingConfirmationCommand, at date: Date) throws {
        switch command {
            case let .notYet(id):
                let index = try pendingIndex(id)
                guard decisions[index].postponementCount >= 3 || date >= decisions[index].confirmationEligibleAt
                else { throw ViewingDecisionError.staleDecision }
                decisions[index].postponementCount += 1
                decisions[index].nextConfirmationAt = date.addingTimeInterval(24 * 3600)
                decisions[index].changedAt = date
            case let .notWatched(id):
                let index = try pendingIndex(id)
                decisions[index].status = .notWatched
                decisions[index].changedAt = max(date, decisions[index].changedAt)
                closeSession(for: id, at: date)
            case let .prepare(operation):
                guard !confirmationOperations.contains(where: { $0.id == operation.id }),
                      let decision = decisions.first(where: { $0.id == operation.decisionID }),
                      decision.recommendation.movieID == operation.movieID,
                      operation.createdAt >= decision.pickedAt, operation.stage == .prepared,
                      !confirmationOperations.contains(where: {
                          $0.decisionID == operation.decisionID && ($0.reaction == nil) == (operation.reaction == nil)
                      })
                else { throw ViewingDecisionError.staleDecision }
                if operation.reaction == nil {
                    _ = try pendingIndex(operation.decisionID)
                    guard decision.postponementCount >= 3 || operation.createdAt >= decision.confirmationEligibleAt
                    else {
                        throw ViewingDecisionError.staleDecision
                    }
                } else {
                    guard decision.status == .confirmedWatched, decision.satisfaction == nil else {
                        throw ViewingDecisionError.staleDecision
                    }
                }
                confirmationOperations.append(operation)
            case let .advance(id, stage):
                guard let index = confirmationOperations.firstIndex(where: { $0.id == id }),
                      let decisionIndex = decisions
                      .firstIndex(where: { $0.id == confirmationOperations[index].decisionID })
                else { throw ViewingDecisionError.staleDecision }
                let stages: [ViewingConfirmationOperation.Stage] = [
                    .prepared, .applyingViewerMovieState, .viewerMovieStateCommitted, .completed,
                ]
                let current = confirmationOperations[index].stage
                if current == stage { return }
                guard let position = stages.firstIndex(of: current),
                      stages.dropFirst(position + 1).first == stage
                else {
                    throw ViewingDecisionError.staleDecision
                }
                confirmationOperations[index].stage = stage
                if stage == .completed {
                    let operation = confirmationOperations[index]
                    if let reaction = operation.reaction {
                        decisions[decisionIndex].satisfaction = reaction
                    } else {
                        decisions[decisionIndex].status = .confirmedWatched
                        decisions[decisionIndex].confirmedAt = operation.createdAt
                        closeSession(for: operation.decisionID, at: date)
                    }
                    decisions[decisionIndex].changedAt = max(date, decisions[decisionIndex].changedAt)
                }
        }
    }

    private func pendingIndex(_ id: ViewingDecisionID) throws -> Int {
        guard let index = decisions.firstIndex(where: { $0.id == id && $0.status == .active }),
              !confirmationOperations.contains(where: { $0.decisionID == id && $0.stage != .completed })
        else { throw ViewingDecisionError.staleDecision }
        return index
    }

    private mutating func closeSession(for id: ViewingDecisionID, at date: Date) {
        guard let index = sessions.firstIndex(where: { $0.status == .open && $0.finalDecisionID == id }) else { return }
        sessions[index].status = .decided
        let deadline = sessions[index].lastActivityAt.addingTimeInterval(30 * 60)
        sessions[index].endedAt = max(sessions[index].lastActivityAt, min(date, deadline))
        sessions[index].foregroundAnchor = nil
    }
}
