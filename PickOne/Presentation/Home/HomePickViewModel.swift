import Foundation
import Observation

@MainActor
@Observable
final class HomePickViewModel {
    private let manage: ManageViewingDecision
    private let clock: @Sendable () -> DecisionMoment
    private let sleep: @Sendable (Duration) async throws -> Void
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
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
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
        guard let homeSurface, homeSurface.recommendations.contains(where: { $0.movieID == movieID }) else {
            hideSurface()
            return
        }
        detailSurface = homeSurface
        if isVisible { enqueue(.observe(homeSurface)) }
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

    private func enqueue(_ operation: ViewingDecisionOperation, movieID: Int?) {
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                _ = try await manage.apply(operation)
                let snapshot = try await manage.snapshot()
                activeDecision = snapshot.activeDecision
                scheduleDeadline(snapshot.openSession)
                if let movieID {
                    pendingOperations[movieID] = nil
                    failedMovieIDs.remove(movieID)
                }
            } catch is CancellationError {
                // Task cancellation is never an explicit Pick cancellation.
            } catch {
                if let movieID { failedMovieIDs.insert(movieID) }
            }
            if let movieID { savingMovieIDs.remove(movieID) }
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
