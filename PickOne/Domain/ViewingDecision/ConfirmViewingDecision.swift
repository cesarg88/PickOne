import Foundation

/// Serializes reconciliation while each repository remains its own durable authority.
protocol ViewingConfirmationMovieStateRepository: ViewerMovieStateRepository {
    func hasAppliedConfirmationOperation(_ id: UUID) async throws -> Bool
}

actor ConfirmViewingDecision {
    private let decisions: any ViewingDecisionRepository
    private let viewerState: any ViewingConfirmationMovieStateRepository
    private let metadata: @Sendable (Int) async throws -> MovieFeedbackMetadata
    private let moment: @Sendable () -> DecisionMoment
    private var reconciliation: Task<Void, Error>?
    private var reconciliationID = UUID()

    init(
        decisions: any ViewingDecisionRepository,
        viewerState: any ViewingConfirmationMovieStateRepository,
        metadata: @escaping @Sendable (Int) async throws -> MovieFeedbackMetadata,
        moment: @escaping @Sendable () -> DecisionMoment
    ) {
        self.decisions = decisions
        self.viewerState = viewerState
        self.metadata = metadata
        self.moment = moment
    }

    func displayMetadata(movieID: Int) async throws -> MovieFeedbackMetadata {
        if let state = try await viewerState.state(movieID: movieID) { return state.displayMetadata }
        return try await metadata(movieID)
    }

    func snapshot() async throws -> ViewingDecisionState {
        try await decisions.snapshot()
    }

    func answer(_ command: ViewingConfirmationCommand, operationID: UUID) async throws {
        try Task.checkCancellation()
        _ = try await decisions.apply(.init(id: operationID, action: .confirmation(command), moment: moment()))
    }

    func confirm(_ id: ViewingDecisionID, operationID: UUID, reaction: MovieReaction? = nil) async throws {
        try Task.checkCancellation()
        let state = try await decisions.snapshot()
        // A retry resumes the original journal and its timestamp, never a new outcome.
        if let existing = state.confirmationOperations.first(where: { $0.id == operationID }) {
            guard existing.decisionID == id,
                  existing.reaction == reaction else { throw ViewingDecisionError.staleDecision }
        } else {
            guard let decision = state.decisions.first(where: { $0.id == id })
            else { throw ViewingDecisionError.staleDecision }
            let operation = ViewingConfirmationOperation(
                id: operationID, decisionID: id, movieID: decision.recommendation.movieID,
                createdAt: moment().wall, reaction: reaction
            )
            try await answer(.prepare(operation), operationID: operationID)
        }
        try await reconcile()
    }

    func reconcile() async throws {
        while let previous = reconciliation {
            let previousID = reconciliationID
            do { try await previous.value } catch {
                if reconciliationID == previousID { reconciliation = nil }
                throw error
            }
            if reconciliationID == previousID { reconciliation = nil }
        }
        let id = UUID()
        reconciliationID = id
        let task = Task { try await self.resumeOperations() }
        reconciliation = task
        defer { if reconciliationID == id { reconciliation = nil } }
        try await task.value
    }

    private func resumeOperations() async throws {
        // Repeat the snapshot so operations prepared while awaiting another store are included.
        while let operation = try await decisions.snapshot().confirmationOperations
            .first(where: { $0.stage != .completed })
        {
            switch operation.stage {
                case .prepared:
                    try await advance(operation, to: .applyingViewerMovieState)
                case .applyingViewerMovieState:
                    if try await viewerState.hasAppliedConfirmationOperation(operation.id) {
                        try await advance(operation, to: .viewerMovieStateCommitted)
                        continue
                    }
                    let current = try await viewerState.state(movieID: operation.movieID)
                    let display: MovieFeedbackMetadata = if let current {
                        current.displayMetadata
                    } else {
                        try await metadata(operation.movieID)
                    }
                    let action: ViewerMovieStateTransition.Action = if let reaction = operation.reaction {
                        .confirmationReaction(reaction, operationID: operation.id)
                    } else {
                        .confirmPick(PickOneViewingProvenance(
                            confirmationOperationID: operation.id,
                            confirmedAt: operation.createdAt
                        ))
                    }
                    _ = try await viewerState.apply(
                        .init(movieID: operation.movieID, action: action),
                        metadata: display
                    )
                    try await advance(operation, to: .viewerMovieStateCommitted)
                case .viewerMovieStateCommitted:
                    try await advance(operation, to: .completed)
                case .completed: break
            }
        }
    }

    private func advance(
        _ operation: ViewingConfirmationOperation,
        to stage: ViewingConfirmationOperation.Stage
    ) async throws {
        _ = try await decisions.apply(.init(action: .confirmation(.advance(operation.id, stage)), moment: moment()))
    }
}
