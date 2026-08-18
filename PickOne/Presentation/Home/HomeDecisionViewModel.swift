import Foundation
import Observation

enum HomeDecisionViewState: Equatable {
    case idle
    case loading
    case loaded(
        HomeDecisionSetPresentationModel,
        isRefreshing: Bool,
        refreshError: String?
    )
    case empty(isRefreshing: Bool, refreshError: String?)
    case failure(String)
}

@MainActor
@Observable
final class HomeDecisionViewModel {
    private let threeForTonight: any ThreeForTonightUseCase
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var activeOperationID = UUID()

    var state: HomeDecisionViewState = .idle

    init(threeForTonight: any ThreeForTonightUseCase) {
        self.threeForTonight = threeForTonight
    }

    func load() {
        start(.load)
    }

    func refresh() {
        start(.refresh)
    }

    func repair(after change: DecisionEligibilityChange) {
        start(.repair(change))
    }

    private func start(_ operation: Operation) {
        activeTask?.cancel()
        let operationID = UUID()
        activeOperationID = operationID
        prepareState(for: operation)
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await operation.execute(with: threeForTonight)
                try Task.checkCancellation()
                guard activeOperationID == operationID else { return }
                apply(result)
            } catch is CancellationError {
                return
            } catch {
                guard activeOperationID == operationID else { return }
                state = .failure("Tonight's picks couldn't be loaded. Please try again.")
            }
        }
    }

    private func prepareState(for operation: Operation) {
        switch operation {
            case .load:
                if case .idle = state {
                    state = .loading
                } else if case .failure = state {
                    state = .loading
                }
            case .refresh, .repair:
                switch state {
                    case let .loaded(set, _, refreshError):
                        state = .loaded(set, isRefreshing: true, refreshError: refreshError)
                    case let .empty(_, refreshError):
                        state = .empty(isRefreshing: true, refreshError: refreshError)
                    case .idle, .failure:
                        state = .loading
                    case .loading:
                        break
                }
        }
    }

    private func apply(_ result: ThreeForTonightResult) {
        switch result {
            case let .usable(snapshot):
                apply(snapshot: snapshot, refreshError: nil)
            case let .retryableFailure(reason, retained):
                guard let retained else {
                    state = .failure(blockingMessage(for: reason))
                    return
                }
                apply(
                    snapshot: retained,
                    refreshError: "Couldn't update tonight's picks. Please try again."
                )
        }
    }

    private func apply(
        snapshot: ThreeForTonightSnapshot,
        refreshError: String?
    ) {
        let model = HomeDecisionPresentationMapper.map(snapshot: snapshot)
        if model.items.isEmpty {
            state = .empty(isRefreshing: false, refreshError: refreshError)
        } else {
            state = .loaded(
                model,
                isRefreshing: false,
                refreshError: refreshError
            )
        }
    }

    private func blockingMessage(for reason: ThreeForTonightFailureReason) -> String {
        switch reason {
            case .profileUnavailable:
                "Your preferences couldn't be loaded. Please try again."
            case .watchlistUnavailable:
                "Your Watchlist couldn't be checked safely. Please try again."
            case .persistenceFailed:
                "Tonight's picks couldn't be saved. Please try again."
            case .recoveryFailed:
                "Saved picks couldn't be recovered. Your other data is unchanged."
            case .generationUnavailable,
                 .repairFailed,
                 .trustedInputsChanged,
                 .invariantViolation:
                "Tonight's picks couldn't be loaded. Please try again."
        }
    }
}

private extension HomeDecisionViewModel {
    enum Operation {
        case load
        case refresh
        case repair(DecisionEligibilityChange)

        func execute(
            with useCase: any ThreeForTonightUseCase
        ) async throws -> ThreeForTonightResult {
            switch self {
                case .load:
                    try await useCase.load()
                case .refresh:
                    try await useCase.refresh()
                case let .repair(change):
                    try await useCase.repairAfterEligibilityChange(change)
            }
        }
    }
}
