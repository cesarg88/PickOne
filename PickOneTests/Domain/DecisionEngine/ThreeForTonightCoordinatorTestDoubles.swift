import Foundation
@testable import PickOne
import Synchronization

final class MutableTrustedDecisionStateLoader: TrustedDecisionStateLoading, Sendable {
    private struct State: Sendable {
        var current: TrustedDecisionState
        var next: TrustedDecisionState?
        var statesByMatchCall: [Int: TrustedDecisionState]
        var matchCallCount = 0
    }

    private let state: Mutex<State>

    init(
        current: TrustedDecisionState,
        next: TrustedDecisionState? = nil,
        switchOnMatchCall: Int? = nil
    ) {
        let statesByMatchCall: [Int: TrustedDecisionState] = if let switchOnMatchCall,
                                                                let next
        {
            [switchOnMatchCall: next]
        } else {
            [:]
        }
        state = Mutex(State(
            current: current,
            next: next,
            statesByMatchCall: statesByMatchCall
        ))
    }

    init(
        current: TrustedDecisionState,
        statesByMatchCall: [Int: TrustedDecisionState]
    ) {
        state = Mutex(State(
            current: current,
            next: nil,
            statesByMatchCall: statesByMatchCall
        ))
    }

    func load() -> TrustedDecisionState {
        state.withLock { $0.current }
    }

    func matches(snapshotID: ViewerStateSnapshotID) -> Bool {
        state.withLock { state in
            state.matchCallCount += 1
            if let scheduledState = state.statesByMatchCall[state.matchCallCount] {
                state.current = scheduledState
            }
            return state.current.snapshotID == snapshotID
        }
    }

    func publishNext() {
        state.withLock { state in
            guard let next = state.next else { return }
            state.current = next
        }
    }
}

actor CoordinatorProfileRepository: ViewerProfileRepository {
    let profile: ViewerProfile

    init(profile: ViewerProfile) {
        self.profile = profile
    }

    func loadState() -> ViewerProfileLoadState {
        .completed(profile: profile, recalibrationDraft: nil)
    }

    func beginFirstOnboarding(catalog _: CalibrationCatalog) throws -> FirstOnboardingDraft {
        throw error
    }

    func saveFirstOnboardingDraft(_: FirstOnboardingDraft) throws {
        throw error
    }

    func beginCalibration(
        from _: FirstOnboardingDraft,
        snapshot _: CalibrationCatalogSnapshot?
    ) throws -> FirstOnboardingDraft {
        throw error
    }

    func completeFirstOnboarding() throws -> ViewerProfile {
        throw error
    }

    func beginRecalibration(snapshot _: CalibrationCatalogSnapshot) throws -> RecalibrationDraft {
        throw error
    }

    func saveRecalibrationDraft(_: RecalibrationDraft) throws {
        throw error
    }

    func completeRecalibration() throws -> ViewerProfile {
        throw error
    }

    func updateServices(_: [PilotStreamingService]) throws -> ViewerProfile {
        throw error
    }

    func resetDraft() throws {
        throw error
    }

    func resetProfileAndDraft() throws {
        throw error
    }

    private var error: ViewerProfileRepositoryError {
        .invalidTransition
    }
}

struct CoordinatorViewerMovieStateRepository: ViewerMovieStateRepository {
    static let defaultSnapshotID = ViewerStateSnapshotID(rawValue: UUID())

    let snapshotID: ViewerStateSnapshotID
    let states: [ViewerMovieState]

    init(
        snapshotID: ViewerStateSnapshotID = Self.defaultSnapshotID,
        states: [ViewerMovieState] = []
    ) {
        self.snapshotID = snapshotID
        self.states = states
    }

    func loadState() -> ViewerMovieStateLoadState {
        .absent
    }

    func snapshot() throws -> ViewerMovieStateSnapshot {
        try ViewerMovieStateSnapshot(id: snapshotID, states: states)
    }

    func state(movieID _: Int) throws -> ViewerMovieState? {
        nil
    }

    func apply(
        _: ViewerMovieStateTransition,
        metadata _: MovieFeedbackMetadata
    ) throws -> ViewerMovieStateChange {
        throw ViewerMovieStateRepositoryError.invalidMovieID
    }
}

enum CoordinatorTestError: Error { case unavailable }

actor CoordinatorCandidateRepository: DecisionCandidateRepository {
    private let candidatesByPage: [Int: [DecisionCandidateSeed]]
    private let error: CoordinatorTestError?
    private let delay: Duration?
    private let failureStartingAtRequest: Int?
    private(set) var requestedPages: [Int] = []

    init(
        candidatesByPage: [Int: [DecisionCandidateSeed]] = [:],
        error: CoordinatorTestError? = nil,
        delay: Duration? = nil,
        failureStartingAtRequest: Int? = nil
    ) {
        self.candidatesByPage = candidatesByPage
        self.error = error
        self.delay = delay
        self.failureStartingAtRequest = failureStartingAtRequest
    }

    func discoverPage(
        _ page: Int,
        context _: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed] {
        requestedPages.append(page)
        if let delay { try await Task.sleep(for: delay) }
        if let error {
            if let failureStartingAtRequest {
                if requestedPages.count >= failureStartingAtRequest {
                    throw error
                }
            } else {
                throw error
            }
        }
        return candidatesByPage[page] ?? []
    }
}

actor CoordinatorAvailabilityRepository: AvailabilityRepository {
    private let evidenceByMovieID: [Int: VerifiedAvailabilityEvidence]
    private let failingMovieIDs: Set<Int>
    private(set) var requests: [CoordinatorAvailabilityRequest] = []

    var requestedMovieIDs: [Int] {
        requests.map(\.movieID)
    }

    init(
        evidenceByMovieID: [Int: VerifiedAvailabilityEvidence] = [:],
        failingMovieIDs: Set<Int> = []
    ) {
        self.evidenceByMovieID = evidenceByMovieID
        self.failingMovieIDs = failingMovieIDs
    }

    func getVerifiedEvidence(
        movieID: Int,
        region _: ViewingRegion,
        policy: AvailabilityFetchPolicy
    ) throws -> VerifiedAvailabilityEvidence? {
        requests.append(CoordinatorAvailabilityRequest(
            movieID: movieID,
            policy: policy
        ))
        if failingMovieIDs.contains(movieID) {
            throw CoordinatorTestError.unavailable
        }
        return evidenceByMovieID[movieID]
    }
}

struct CoordinatorAvailabilityRequest: Equatable, Sendable {
    let movieID: Int
    let policy: AvailabilityFetchPolicy
}

actor CoordinatorDecisionSetRepository: DecisionSetRepository {
    private var loadResult: DecisionSetLoadResult
    let replaceError: CoordinatorTestError?
    let onReplace: @Sendable () -> Void
    private(set) var replacements: [PersistedDecisionSet] = []
    private var checkpoints: [DecisionSetPersistenceCheckpoint: DecisionSetLoadResult] = [:]

    init(
        loadResult: DecisionSetLoadResult,
        replaceError: CoordinatorTestError? = nil,
        onReplace: @escaping @Sendable () -> Void = {}
    ) {
        self.loadResult = loadResult
        self.replaceError = replaceError
        self.onReplace = onReplace
    }

    func load() -> DecisionSetLoadResult {
        loadResult
    }

    func replace(_ envelope: PersistedDecisionSet) throws {
        if let replaceError { throw replaceError }
        replacements.append(envelope)
        loadResult = .available(envelope)
        onReplace()
    }

    func makePersistenceCheckpoint() -> DecisionSetPersistenceCheckpoint {
        let checkpoint = DecisionSetPersistenceCheckpoint()
        checkpoints.removeAll(keepingCapacity: true)
        checkpoints[checkpoint] = loadResult
        return checkpoint
    }

    func restorePersistenceCheckpoint(
        _ checkpoint: DecisionSetPersistenceCheckpoint
    ) throws {
        guard let saved = checkpoints.removeValue(forKey: checkpoint) else {
            throw CoordinatorTestError.unavailable
        }
        loadResult = saved
    }
}

actor CoordinatorMovieRepository: MovieRepository {
    private let movies: [Int: Movie]

    init(movies: [Int: Movie] = [:]) {
        self.movies = movies
    }

    func getMovieDetail(id: Int, policy _: CachePolicy) throws -> CacheResult<Movie> {
        guard let movie = movies[id] else { throw CoordinatorTestError.unavailable }
        return CacheResult(value: movie, isStale: false)
    }

    func getTopRated(page _: Int, policy _: CachePolicy) throws -> CacheResult<MoviePage> {
        throw error
    }

    func getSimilarMovies(id _: Int, page _: Int, policy _: CachePolicy) throws -> CacheResult<MoviePage> {
        throw error
    }

    func getCredits(id _: Int, policy _: CachePolicy) throws -> CacheResult<Credits> {
        throw error
    }

    func searchMovies(query _: String, page _: Int) throws -> MoviePage {
        throw error
    }

    private var error: CoordinatorTestError {
        .unavailable
    }
}
