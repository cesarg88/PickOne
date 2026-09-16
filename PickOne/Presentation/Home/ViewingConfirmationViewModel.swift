import Foundation
import Observation

@MainActor
@Observable
final class ViewingConfirmationViewModel {
    private let coordinator: ConfirmViewingDecision
    private let now: @Sendable () -> Date
    private let didChange: @MainActor () -> Void
    private var generation = UUID()
    private var pendingAction: PendingAction?
    private var actionTask: Task<Void, Never>?
    private(set) var automatic: ViewingDecision?
    private(set) var manual: [ViewingDecision] = []
    private(set) var satisfaction: ViewingDecision?
    private(set) var titles: [Int: String] = [:]
    private(set) var isSaving = false
    private(set) var failure = false

    private enum ActionKind { case watched, notYet, notWatched, reaction(MovieReaction) }

    private struct PendingAction {
        let id = UUID()
        let decision: ViewingDecision
        let kind: ActionKind
    }

    init(
        coordinator: ConfirmViewingDecision,
        now: @escaping @Sendable () -> Date = Date.init,
        didChange: @escaping @MainActor () -> Void = {}
    ) {
        self.coordinator = coordinator
        self.now = now
        self.didChange = didChange
    }

    func refresh() async {
        let token = UUID()
        generation = token
        do {
            do { try await coordinator.reconcile() } catch {
                guard generation == token else { return }
                failure = true
            }
            let state = try await coordinator.snapshot()
            try Task.checkCancellation()
            guard generation == token else { return }
            automatic = state.activeDecision.flatMap { $0.isAutomaticallyEligible(at: now()) ? $0 : nil }
            manual = state.manualConfirmations
            for decision in manual + [automatic].compactMap({ $0 }) {
                let metadata = try? await coordinator.displayMetadata(movieID: decision.recommendation.movieID)
                guard generation == token, !Task.isCancelled else { return }
                if let metadata { titles[decision.recommendation.movieID] = metadata.title }
            }
        } catch {
            // A measurement failure must not replace the core Home or My movies state.
            guard generation == token else { return }
            automatic = nil
            manual = []
            failure = true
        }
    }

    func watched(_ decision: ViewingDecision) {
        submit(decision, kind: .watched)
    }

    func postpone(_ decision: ViewingDecision) {
        submit(decision, kind: .notYet)
    }

    func notWatched(_ decision: ViewingDecision) {
        submit(decision, kind: .notWatched)
    }

    func react(_ reaction: MovieReaction, to decision: ViewingDecision) {
        submit(decision, kind: .reaction(reaction))
    }

    func skipSatisfaction() {
        guard !isSaving, !failure else { return }; satisfaction = nil; failure = false; pendingAction = nil
    }

    func retry() {
        guard !isSaving else { return }
        if let pendingAction {
            run(pendingAction)
        } else {
            failure = false
            actionTask = Task { await refresh() }
        }
    }

    func waitForAction() async {
        await actionTask?.value
    }

    private func submit(_ decision: ViewingDecision, kind: ActionKind) {
        guard !isSaving, pendingAction == nil else { return }
        let action = PendingAction(decision: decision, kind: kind)
        pendingAction = action
        run(action)
    }

    private func run(_ action: PendingAction) {
        isSaving = true
        failure = false
        generation = UUID()
        actionTask = Task {
            defer { isSaving = false }
            do {
                switch action.kind {
                    case .watched:
                        try await coordinator.confirm(action.decision.id, operationID: action.id)
                        satisfaction = action.decision
                    case .notYet:
                        try await coordinator.answer(.notYet(action.decision.id), operationID: action.id)
                    case .notWatched:
                        try await coordinator.answer(.notWatched(action.decision.id), operationID: action.id)
                    case let .reaction(reaction):
                        try await coordinator.confirm(action.decision.id, operationID: action.id, reaction: reaction)
                        satisfaction = nil
                }
                pendingAction = nil
                notifyViewerStateChange(action.kind)
                await refresh()
            } catch {
                failure = true
                // Watched/provenance may already be durable even if the journal needs retry.
                notifyViewerStateChange(action.kind)
            }
        }
    }

    private func notifyViewerStateChange(_ kind: ActionKind) {
        switch kind {
            case .watched, .reaction: didChange()
            case .notYet, .notWatched: break
        }
    }
}
