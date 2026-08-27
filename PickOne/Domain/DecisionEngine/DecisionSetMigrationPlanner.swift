import Foundation

struct DecisionSetMigrationPlanner: Sendable {
    func reconciledCycle(
        sourceCycle: DecisionCycle,
        currentSignature: DecisionCycleSignature,
        makeCycleID: @Sendable () -> UUID
    ) throws -> DecisionCycle {
        if sourceCycle.identitySignature == currentSignature {
            return sourceCycle
        }

        return try DecisionCycle(
            id: makeCycleID(),
            identitySignature: currentSignature,
            shownMovieIDs: sourceCycle.shownMovieIDs
        )
    }
}
