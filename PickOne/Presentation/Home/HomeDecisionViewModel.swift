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

struct HomeDecisionExhaustionPresentation: Equatable {
    let recommendationCount: Int
    let expiresAt: Date
    var canRefresh: Bool
}

@MainActor
@Observable
final class HomeDecisionViewModel {
    let pickModel: HomePickViewModel?
    private let threeForTonight: any ThreeForTonightUseCase
    private let getMovieDisplayMetadata: (any GetMovieDisplayMetadataUseCase)?
    @ObservationIgnored private var contentLocale = MovieContentLocale(effectiveLocale: .current)
    @ObservationIgnored private var activeSnapshot: ThreeForTonightSnapshot?
    @ObservationIgnored private var displayProjection = HomeMovieDisplayProjection()
    @ObservationIgnored private var displayTask: Task<Void, Never>?
    @ObservationIgnored private var displayLoadID = UUID()
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var activeOperationID = UUID()
    @ObservationIgnored private var activeOperation: Operation?
    @ObservationIgnored private var pendingReconciliations: [Operation] = []
    @ObservationIgnored private var isReconciliationPending = false
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var exhaustionTask: Task<Void, Never>?
    @ObservationIgnored private let feedbackDuration: Duration
    @ObservationIgnored private let feedbackSleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let exhaustionSleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var isHomeVisible = false
    @ObservationIgnored private var isUpdateFeedbackPending = false

    var state: HomeDecisionViewState = .idle
    var updateFeedback: String?
    var exhaustion: HomeDecisionExhaustionPresentation?

    init(
        threeForTonight: any ThreeForTonightUseCase,
        getMovieDisplayMetadata: (any GetMovieDisplayMetadataUseCase)? = nil,
        pickModel: HomePickViewModel? = nil,
        feedbackDuration: Duration = .seconds(3),
        feedbackSleep: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        },
        now: @escaping @Sendable () -> Date = Date.init,
        exhaustionSleep: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.pickModel = pickModel
        self.threeForTonight = threeForTonight
        self.getMovieDisplayMetadata = getMovieDisplayMetadata
        self.feedbackDuration = feedbackDuration
        self.feedbackSleep = feedbackSleep
        self.now = now
        self.exhaustionSleep = exhaustionSleep
    }

    func homeDidAppear() {
        guard !isHomeVisible else { return }
        isHomeVisible = true
        presentPendingUpdateFeedback()
        refreshExhaustionFreshness()
    }

    func homeDidDisappear() {
        guard isHomeVisible else { return }
        isHomeVisible = false
        exhaustionTask?.cancel()
        exhaustionTask = nil
        guard updateFeedback != nil else { return }
        feedbackTask?.cancel()
        feedbackTask = nil
        updateFeedback = nil
        isUpdateFeedbackPending = true
    }

    func load() {
        guard activeOperation == nil, pendingReconciliations.isEmpty else {
            isReconciliationPending = true
            return
        }
        start(.load)
    }

    func setContentLocale(_ effectiveLocale: Locale) {
        let next = MovieContentLocale(effectiveLocale: effectiveLocale)
        guard contentLocale != next else { return }
        pickModel?.invalidateTitlesForLocaleChange()
        contentLocale = next
        displayTask?.cancel()
        displayTask = nil
        displayLoadID = UUID()
        displayProjection = HomeMovieDisplayProjection()
        guard let activeSnapshot else { return }
        publishDisplay(for: activeSnapshot, updatePickSurface: false)
        hydrateDisplay(for: activeSnapshot)
    }

    func refresh() {
        guard exhaustion?.canRefresh != false else { return }
        guard activeOperation?.isReconciliation != true,
              pendingReconciliations.isEmpty
        else {
            return
        }
        pickModel?.refreshRequested()
        start(.refresh)
    }

    func appDidBecomeActive() {
        guard isHomeVisible else { return }
        refreshExhaustionFreshness()
    }

    func repair(after change: DecisionEligibilityChange) {
        enqueueReconciliation(.repair(change))
    }

    func reconcile(after change: DecisionViewerStateChange) {
        guard change.impact != .none else { return }
        pickModel?.holdPickUntilSafeSet(movieID: change.movieID)
        enqueueReconciliation(.viewerState(change))
    }

    private func start(_ operation: Operation) {
        activeTask?.cancel()
        let operationID = UUID()
        activeOperationID = operationID
        activeOperation = operation
        prepareState(for: operation)
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await operation.execute(with: threeForTonight)
                try Task.checkCancellation()
                guard activeOperationID == operationID else { return }
                apply(result, operation: operation)
                finish(operationID: operationID)
            } catch is CancellationError {
                guard activeOperationID == operationID else { return }
                finish(operationID: operationID)
                return
            } catch {
                guard activeOperationID == operationID else { return }
                clearDisplaySnapshot()
                pickModel?.updateSurface(nil)
                state = .failure(String(localized: "Tonight's picks couldn't be loaded. Please try again."))
                finish(operationID: operationID)
            }
        }
    }

    private func finish(operationID: UUID) {
        guard activeOperationID == operationID else { return }
        activeTask = nil
        activeOperation = nil
        if !pendingReconciliations.isEmpty {
            start(pendingReconciliations.removeFirst())
        } else if isReconciliationPending {
            isReconciliationPending = false
            start(.load)
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
            case .refresh, .repair, .viewerState:
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

    private func apply(
        _ result: ThreeForTonightResult,
        operation: Operation
    ) {
        switch result {
            case let .usable(snapshot):
                exhaustionTask?.cancel()
                exhaustionTask = nil
                exhaustion = nil
                apply(snapshot: snapshot, refreshError: nil)
                if operation.isReconciliation {
                    coalesceViewerStateChanges(
                        through: snapshot.decisionSet.sourceViewerStateSnapshotID
                    )
                    enqueueUpdateFeedback()
                }
                releasePickHoldsIfSafe()
            case let .exhausted(exhausted):
                apply(snapshot: exhausted.snapshot, refreshError: nil)
                exhaustion = HomeDecisionExhaustionPresentation(
                    recommendationCount: exhausted.snapshot.decisionSet.recommendations.count,
                    expiresAt: exhausted.expiresAt,
                    canRefresh: exhausted.canRefresh
                )
                scheduleExhaustionDeadlineIfNeeded()
                if operation.isReconciliation {
                    coalesceViewerStateChanges(
                        through: exhausted.snapshot.decisionSet
                            .sourceViewerStateSnapshotID
                    )
                    enqueueUpdateFeedback()
                }
                releasePickHoldsIfSafe()
            case let .retryableFailure(reason, retained):
                guard let retained else {
                    clearExhaustion()
                    clearDisplaySnapshot()
                    pickModel?.updateSurface(nil)
                    state = .failure(blockingMessage(for: reason))
                    return
                }
                clearExhaustion()
                apply(
                    snapshot: retained,
                    refreshError: String(localized: "Couldn't update tonight's picks. Please try again.")
                )
        }
    }

    private func clearExhaustion() {
        exhaustionTask?.cancel()
        exhaustionTask = nil
        exhaustion = nil
    }

    private func refreshExhaustionFreshness() {
        guard var exhaustion else { return }
        exhaustion.canRefresh = now() >= exhaustion.expiresAt
        self.exhaustion = exhaustion
        scheduleExhaustionDeadlineIfNeeded()
    }

    private func scheduleExhaustionDeadlineIfNeeded() {
        exhaustionTask?.cancel()
        exhaustionTask = nil
        guard isHomeVisible, let exhaustion, !exhaustion.canRefresh else { return }
        let interval = max(0, exhaustion.expiresAt.timeIntervalSince(now()))
        let sleep = exhaustionSleep
        exhaustionTask = Task { [weak self] in
            do {
                try await sleep(.seconds(interval))
                try Task.checkCancellation()
                guard var current = self?.exhaustion,
                      current.expiresAt == exhaustion.expiresAt
                else {
                    return
                }
                current.canRefresh = true
                self?.exhaustion = current
                self?.exhaustionTask = nil
            } catch {
                return
            }
        }
    }

    private func enqueueReconciliation(_ operation: Operation) {
        if activeOperation?.isReconciliation == true {
            if !pendingReconciliations.contains(operation) {
                pendingReconciliations.append(operation)
            }
            return
        }
        start(operation)
    }

    private func coalesceViewerStateChanges(
        through publishedSnapshotID: ViewerStateSnapshotID
    ) {
        guard let publishedIndex = pendingReconciliations.firstIndex(where: {
            $0.viewerStateSnapshotID == publishedSnapshotID
        }) else {
            return
        }
        let supersededSnapshotIDs = Set(
            pendingReconciliations[...publishedIndex]
                .compactMap(\.viewerStateSnapshotID)
        )
        pendingReconciliations.removeAll { operation in
            guard let snapshotID = operation.viewerStateSnapshotID else { return false }
            return supersededSnapshotIDs.contains(snapshotID)
        }
    }

    private func enqueueUpdateFeedback() {
        isUpdateFeedbackPending = true
        presentPendingUpdateFeedback()
    }

    private func presentPendingUpdateFeedback() {
        guard isHomeVisible, isUpdateFeedbackPending else { return }
        isUpdateFeedbackPending = false
        feedbackTask?.cancel()
        updateFeedback = String(localized: "Recommendations updated.")
        let duration = feedbackDuration
        let sleep = feedbackSleep
        feedbackTask = Task { [weak self] in
            do {
                try await sleep(duration)
                try Task.checkCancellation()
                self?.updateFeedback = nil
                self?.feedbackTask = nil
            } catch {
                return
            }
        }
    }

    private func apply(
        snapshot: ThreeForTonightSnapshot,
        refreshError: String?
    ) {
        let priorSetID = activeSnapshot?.decisionSet.id
        activeSnapshot = snapshot
        if priorSetID != snapshot.decisionSet.id {
            displayProjection = HomeMovieDisplayProjection()
        }
        publishDisplay(for: snapshot, refreshError: refreshError, updatePickSurface: true)
        hydrateDisplay(for: snapshot)
    }

    private func publishDisplay(
        for snapshot: ThreeForTonightSnapshot,
        refreshError: String? = nil,
        updatePickSurface: Bool
    ) {
        let presentationStatus: (isRefreshing: Bool, refreshError: String?) = if updatePickSurface {
            (false, refreshError)
        } else if case let .loaded(_, isRefreshing, existingError) = state {
            (isRefreshing, existingError)
        } else if case let .empty(isRefreshing, existingError) = state {
            (isRefreshing, existingError)
        } else {
            (false, refreshError)
        }
        let model = HomeDecisionPresentationMapper.map(
            snapshot: snapshot,
            locale: contentLocale.locale,
            projection: displayProjection
        )
        for item in model.items where item.hasCurrentLocaleTitle {
            pickModel?.rememberProjectedTitle(item.title, movieID: item.id)
        }
        let visibleIDs = Set(model.items.map(\.id))
        if updatePickSurface {
            pickModel?.updateSurface(try? ViewingDecisionSurface(
                recommendations: snapshot.decisionSet.recommendations.filter {
                    visibleIDs.contains($0.display.movieID)
                }.map {
                    PickRecommendation(
                        movieID: $0.display.movieID,
                        setID: snapshot.decisionSet.id,
                        cycleID: snapshot.decisionSet.cycle.id,
                        role: $0.role
                    )
                }
            ))
        }
        if model.items.isEmpty {
            state = .empty(
                isRefreshing: presentationStatus.isRefreshing,
                refreshError: presentationStatus.refreshError
            )
        } else {
            state = .loaded(
                model,
                isRefreshing: presentationStatus.isRefreshing,
                refreshError: presentationStatus.refreshError
            )
        }
    }

    private func clearDisplaySnapshot() {
        displayTask?.cancel()
        displayTask = nil
        displayLoadID = UUID()
        activeSnapshot = nil
        displayProjection = HomeMovieDisplayProjection()
    }

    private func hydrateDisplay(for snapshot: ThreeForTonightSnapshot) {
        displayTask?.cancel()
        guard let getMovieDisplayMetadata else { return }
        let loadID = UUID()
        displayLoadID = loadID
        let locale = contentLocale
        let loader = HomeMovieDisplayLoader(getMovieDisplayMetadata: getMovieDisplayMetadata)
        displayTask = Task { [weak self] in
            let projection = await loader.load(snapshot: snapshot, contentLocale: locale)
            guard let self,
                  !Task.isCancelled,
                  displayLoadID == loadID,
                  contentLocale == locale,
                  let activeSnapshot,
                  activeSnapshot.decisionSet.id == snapshot.decisionSet.id
            else { return }
            displayProjection = projection
            publishDisplay(for: activeSnapshot, updatePickSurface: false)
            displayTask = nil
        }
    }

    private func blockingMessage(for reason: ThreeForTonightFailureReason) -> String {
        switch reason {
            case .profileUnavailable:
                String(localized: "Your preferences couldn't be loaded. Please try again.")
            case .persistenceFailed:
                String(localized: "Tonight's picks couldn't be saved. Please try again.")
            case .recoveryFailed:
                String(localized: "Saved picks couldn't be recovered. Your other data is unchanged.")
            case .generationUnavailable,
                 .repairFailed,
                 .trustedInputsChanged,
                 .invariantViolation:
                String(localized: "Tonight's picks couldn't be loaded. Please try again.")
        }
    }
}

private extension HomeDecisionViewModel {
    func releasePickHoldsIfSafe() {
        guard pendingReconciliations.isEmpty, !isReconciliationPending else { return }
        pickModel?.safeSetDidPublish()
    }

    enum Operation: Equatable {
        case load
        case refresh
        case repair(DecisionEligibilityChange)
        case viewerState(DecisionViewerStateChange)

        var isReconciliation: Bool {
            switch self {
                case .repair, .viewerState:
                    true
                case .load, .refresh:
                    false
            }
        }

        var viewerStateSnapshotID: ViewerStateSnapshotID? {
            guard case let .viewerState(change) = self else { return nil }
            return change.snapshotID
        }

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
                case let .viewerState(change):
                    try await useCase.reconcileAfterViewerStateChange(change)
            }
        }
    }
}
