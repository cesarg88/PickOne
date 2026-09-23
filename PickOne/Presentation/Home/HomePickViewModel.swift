import Foundation
import Observation

@MainActor
@Observable
final class HomePickViewModel {
    private let manage: ManageViewingDecision
    private let clock: @Sendable () -> DecisionMoment
    private let sleep: @Sendable (Duration) async throws -> Void
    private let feedbackSleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    private(set) var isShowingPickFeedback = false
    @ObservationIgnored private var tail: Task<Void, Never>?
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    private var homeSurface: ViewingDecisionSurface?
    private var detailSurface: ViewingDecisionSurface?
    private var isActive = false
    private var isVisible = false
    private(set) var activeDecision: ViewingDecision?
    private(set) var savingMovieIDs: Set<Int> = []
    private(set) var failedMovieIDs: Set<Int> = []
    private var pendingOperations: [Int: ViewingDecisionOperation] = [:]

    init(
        manage: ManageViewingDecision,
        clock: (@Sendable () -> DecisionMoment)? = nil,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        feedbackSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.manage = manage
        let runtimeID = UUID()
        let monotonicClock = ContinuousClock()
        let origin = monotonicClock.now
        self.clock = clock ?? {
            let elapsed = origin.duration(to: monotonicClock.now).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            return DecisionMoment(wall: Date(), monotonicSeconds: seconds, runtimeID: runtimeID)
        }
        self.sleep = sleep
        self.feedbackSleep = feedbackSleep
    }

    func updateSurface(_ surface: ViewingDecisionSurface?) {
        guard homeSurface != surface else { return }
        homeSurface = surface
        if isVisible, detailSurface == nil {
            if let surface { enqueue(.observe(surface)) } else { enqueue(.leaveSurface) }
        }
    }

    func showHome() {
        isVisible = true
        detailSurface = nil
        if let homeSurface { enqueue(.observe(homeSurface)) }
    }

    func showRelatedDetail(movieID: Int) {
        guard let recommendation = homeSurface?.recommendations.first(where: { $0.movieID == movieID }),
              let surface = try? ViewingDecisionSurface(recommendations: [recommendation])
        else {
            hideSurface()
            return
        }
        detailSurface = surface
        if isVisible { enqueue(.observe(surface)) }
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible, let surface = currentSurface {
            enqueue(.observe(surface))
        } else {
            enqueue(.leaveSurface)
        }
    }

    func hideSurface() {
        setVisible(false)
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        enqueue(active ? .activate(isVisible ? currentSurface : nil) : .pause)
    }

    func refreshRequested() {
        guard isVisible, let currentSurface else { return }
        enqueue(.refresh(currentSurface))
    }

    func alreadyWatchedRecorder(movieID: Int) -> @MainActor () -> Void {
        if isVisible, detailSurface == nil, let homeSurface { enqueue(.observe(homeSurface)) }
        let previous = tail
        let manage = manage
        // Capture attribution in the observation queue without delaying the movie-state save.
        let session = Task {
            await previous?.value
            return try? await manage.snapshot().openSession?.id
        }
        tail = Task { _ = await session.value }
        return { [weak self] in
            guard let self else { return }
            let preceding = tail
            let moment = clock()
            tail = Task {
                await preceding?.value
                guard let id = await session.value else { return }
                _ = try? await manage.apply(ViewingDecisionOperation(
                    action: .alreadyWatched(id, movieID: movieID), moment: moment
                ))
            }
        }
    }

    func pick(movieID: Int) {
        guard !savingMovieIDs.contains(movieID), let homeSurface,
              let recommendation = homeSurface.recommendations.first(where: { $0.movieID == movieID })
        else { return }
        submit(
            .pick(recommendation, snapshot: homeSurface, isVisible: isVisible && detailSurface == nil),
            movieID: movieID
        )
    }

    func cancel() {
        guard let activeDecision, !savingMovieIDs.contains(activeDecision.recommendation.movieID) else { return }
        submit(.cancel(activeDecision.id), movieID: activeDecision.recommendation.movieID)
    }

    func retry(movieID: Int) {
        guard !savingMovieIDs.contains(movieID), let operation = pendingOperations[movieID] else { return }
        savingMovieIDs.insert(movieID)
        failedMovieIDs.remove(movieID)
        enqueue(operation, movieID: movieID)
    }

    func waitForPendingOperations() async {
        await tail?.value
    }

    /// Reload durable Pick state after another decision workflow, without recording activity.
    func refreshDecision() async throws {
        let previous = tail
        let refresh = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let snapshot = try await manage.snapshot()
            publish(snapshot)
        }
        tail = Task { _ = try? await refresh.value }
        try await refresh.value
    }

    private func publish(_ snapshot: ViewingDecisionState) {
        activeDecision = snapshot.activeDecision
        if activeDecision == nil {
            feedbackTask?.cancel()
            isShowingPickFeedback = false
        }
        for (movieID, operation) in pendingOperations {
            if case let .cancel(id) = operation.action, id != activeDecision?.id {
                clearPendingOperation(operation, movieID: movieID)
            }
        }
        scheduleDeadline(snapshot.openSession)
    }

    private var currentSurface: ViewingDecisionSurface? {
        detailSurface ?? homeSurface
    }

    private func submit(_ action: ViewingDecisionAction, movieID: Int) {
        let operation = ViewingDecisionOperation(action: action, moment: clock())
        pendingOperations[movieID] = operation
        savingMovieIDs.insert(movieID)
        failedMovieIDs.remove(movieID)
        enqueue(operation, movieID: movieID)
    }

    private func enqueue(_ action: ViewingDecisionAction) {
        enqueue(ViewingDecisionOperation(action: action, moment: clock()), movieID: nil)
    }

    private func isCurrent(_ operation: ViewingDecisionOperation, movieID: Int?) -> Bool {
        guard let movieID else { return true }
        return pendingOperations[movieID]?.id == operation.id
    }

    private func clearPendingOperation(_ operation: ViewingDecisionOperation, movieID: Int) {
        guard isCurrent(operation, movieID: movieID) else { return }
        pendingOperations[movieID] = nil
        savingMovieIDs.remove(movieID)
        failedMovieIDs.remove(movieID)
    }

    private func enqueue(_ operation: ViewingDecisionOperation, movieID: Int?) {
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self, isCurrent(operation, movieID: movieID) else { return }
            defer {
                if let movieID, isCurrent(operation, movieID: movieID) {
                    savingMovieIDs.remove(movieID)
                }
            }
            do {
                _ = try await manage.apply(operation)
                guard isCurrent(operation, movieID: movieID) else { return }
                let snapshot = try await manage.snapshot()
                guard isCurrent(operation, movieID: movieID) else { return }
                let previousDecisionID = activeDecision?.id
                publish(snapshot)
                if case .pick = operation.action, activeDecision != nil, activeDecision?.id != previousDecisionID {
                    showPickFeedback()
                }
                if let movieID {
                    clearPendingOperation(operation, movieID: movieID)
                }
            } catch is CancellationError {
                // Task cancellation is never an explicit Pick cancellation.
            } catch {
                if let movieID, isCurrent(operation, movieID: movieID) {
                    failedMovieIDs.insert(movieID)
                }
            }
        }
    }

    private func showPickFeedback() {
        feedbackTask?.cancel()
        isShowingPickFeedback = true
        let feedbackSleep = feedbackSleep
        feedbackTask = Task { [weak self] in
            do {
                try await feedbackSleep(.seconds(3))
                try Task.checkCancellation()
                self?.isShowingPickFeedback = false
            } catch { return }
        }
    }

    private func scheduleDeadline(_ session: RecommendationSession?) {
        deadlineTask?.cancel()
        deadlineTask = nil
        guard let session else { return }
        let remaining = max(0, session.lastActivityAt.addingTimeInterval(1800).timeIntervalSince(clock().wall))
        let sleep = sleep
        deadlineTask = Task { [weak self] in
            do {
                try await sleep(.seconds(remaining))
                try Task.checkCancellation()
                self?.enqueue(.expire)
            } catch { return }
        }
    }
}
