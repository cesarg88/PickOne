import Foundation

struct ViewingConfirmationOperationDTO: Codable {
    let id: UUID
    let decisionID: UUID
    let movieID: Int
    let createdAt: Date
    let reaction: String?
    let stage: String

    init(_ operation: ViewingConfirmationOperation) {
        id = operation.id
        decisionID = operation.decisionID.rawValue
        movieID = operation.movieID
        createdAt = operation.createdAt
        reaction = operation.reaction?.rawValue
        stage = operation.stage.rawValue
    }

    func domain() throws -> ViewingConfirmationOperation {
        guard let stage = ViewingConfirmationOperation.Stage(rawValue: stage)
        else { throw ViewingDecisionError.invalidData }
        let reaction = try reaction.map { value in
            guard let result = MovieReaction(rawValue: value) else { throw ViewingDecisionError.invalidData }
            return result
        }
        return ViewingConfirmationOperation(
            id: id,
            decisionID: ViewingDecisionID(rawValue: decisionID),
            movieID: movieID,
            createdAt: createdAt,
            reaction: reaction,
            stage: stage
        )
    }
}

extension ViewingDecisionEnvelope {
    func validateConfirmations() throws {
        let operations = state.confirmationOperations
        guard Set(operations.map(\.id)).count == operations.count else { throw ViewingDecisionError.invalidData }
        for decision in state.decisions {
            let related = operations.filter { $0.decisionID == decision.id }
            guard decision.postponementCount >= 0,
                  (decision.postponementCount == 0) == (decision.nextConfirmationAt == nil),
                  decision.nextConfirmationAt.map({ $0 >= decision.pickedAt.addingTimeInterval(24 * 3600) }) ?? true,
                  (decision.status == .confirmedWatched) == (decision.confirmedAt != nil),
                  decision.satisfaction == nil || decision.status == .confirmedWatched,
                  related.count(where: { $0.reaction == nil }) <= 1,
                  related.count(where: { $0.reaction != nil }) <= 1
            else { throw ViewingDecisionError.invalidData }
            if let confirmedAt = decision.confirmedAt {
                guard related
                    .contains(where: { $0.reaction == nil && $0.stage == .completed && $0.createdAt == confirmedAt })
                else {
                    throw ViewingDecisionError.invalidData
                }
            }
            if let reaction = decision.satisfaction {
                guard related.contains(where: { $0.reaction == reaction && $0.stage == .completed }) else {
                    throw ViewingDecisionError.invalidData
                }
            }
        }
        for operation in operations {
            guard let decision = state.decisions.first(where: { $0.id == operation.decisionID }),
                  operation.movieID == decision.recommendation.movieID,
                  operation.createdAt >= decision.pickedAt,
                  operation.reaction == nil || decision.status == .confirmedWatched,
                  operation.stage != .completed || decision.status == .confirmedWatched
            else { throw ViewingDecisionError.invalidData }
            if let reaction = operation.reaction {
                guard operation.stage == .completed
                    ? decision.satisfaction == reaction : decision.satisfaction == nil
                else { throw ViewingDecisionError.invalidData }
            } else if operation.stage != .completed {
                // Another Pick may supersede a prepared confirmation, but cancellation
                // and not-watched answers cannot close it while its journal is pending.
                guard decision.status == .active || decision.status == .superseded else {
                    throw ViewingDecisionError.invalidData
                }
            }
        }
    }
}
