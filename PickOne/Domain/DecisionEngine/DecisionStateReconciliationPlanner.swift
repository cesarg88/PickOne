import Foundation

struct DecisionViewerStateChange: Equatable, Sendable {
    let movieID: Int
    let impact: ViewerMovieStateChangeImpact
    let snapshotID: ViewerStateSnapshotID

    init?(
        movieID: Int,
        impact: ViewerMovieStateChangeImpact,
        snapshotID: ViewerStateSnapshotID
    ) {
        guard movieID > 0 else { return nil }
        self.movieID = movieID
        self.impact = impact
        self.snapshotID = snapshotID
    }
}

enum DecisionStateReconciliationPlan: Equatable, Sendable {
    case none
    case successorCycle(DecisionCycle)
    case repair(movieID: Int)
}

struct DecisionStateReconciliationPlanner: Sendable {
    func plan(
        change: DecisionViewerStateChange,
        sourceCycle: DecisionCycle,
        currentSignature: DecisionCycleSignature,
        makeCycleID: @Sendable () -> UUID
    ) throws -> DecisionStateReconciliationPlan {
        switch change.impact {
            case .tasteChanged:
                try .successorCycle(DecisionCycle(
                    id: makeCycleID(),
                    identitySignature: currentSignature,
                    history: sourceCycle.history
                ))
            case .eligibilityChanged, .watchlistIntentChanged:
                .repair(movieID: change.movieID)
            case .none:
                .none
        }
    }
}
