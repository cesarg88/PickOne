import Foundation
@testable import PickOne

enum FeedbackActionCase: CaseIterable, Sendable {
    case assignReaction
    case removeReaction
    case markWatched
    case markUnwatched
    case setNotInterested
    case removeNotInterested
    case saveToWatchlist
    case removeFromWatchlist

    var currentState: FeedbackSemanticState? {
        switch self {
            case .assignReaction, .markWatched, .setNotInterested, .saveToWatchlist:
                nil
            case .removeReaction:
                FeedbackSemanticState(
                    watchState: .watched,
                    preference: .reaction(.likeIt),
                    watchlistIntent: nil
                )
            case .markUnwatched:
                FeedbackSemanticState(
                    watchState: .watched,
                    preference: nil,
                    watchlistIntent: nil
                )
            case .removeNotInterested:
                FeedbackSemanticState(
                    watchState: .unwatched,
                    preference: .notInterested,
                    watchlistIntent: nil
                )
            case .removeFromWatchlist:
                FeedbackSemanticState(
                    watchState: .unwatched,
                    preference: nil,
                    watchlistIntent: WatchlistIntent(addedAt: .distantPast)
                )
        }
    }

    var expectedAction: ViewerMovieStateTransition.Action {
        switch self {
            case .assignReaction: .assignReaction(.likeIt)
            case .removeReaction: .removeReaction
            case .markWatched: .markWatched
            case .markUnwatched: .markUnwatched
            case .setNotInterested: .setNotInterested
            case .removeNotInterested: .removeNotInterested
            case .saveToWatchlist: .saveToWatchlist
            case .removeFromWatchlist: .removeFromWatchlist
        }
    }

    @MainActor
    func perform(on model: MovieDetailViewModel) async {
        switch self {
            case .assignReaction:
                await model.setReaction(.likeIt)
            case .removeReaction:
                await model.removeReaction()
            case .markWatched, .markUnwatched:
                await model.toggleWatched()
            case .setNotInterested, .removeNotInterested:
                await model.toggleNotInterested()
            case .saveToWatchlist, .removeFromWatchlist:
                await model.toggleWatchlist()
        }
    }
}

struct FeedbackSemanticState: Sendable {
    let watchState: MovieWatchState
    let preference: MoviePreference?
    let watchlistIntent: WatchlistIntent?
}

enum FeedbackLoadOutcome: Sendable {
    case state(ViewerMovieState?)
    case gated(FeedbackOperationGate, ViewerMovieState?)
    case failure
}

actor SequencedFeedbackLoad: GetViewerMovieStateUseCase {
    let outcomes: [FeedbackLoadOutcome]
    private var index = 0

    init(outcomes: [FeedbackLoadOutcome]) {
        self.outcomes = outcomes
    }

    func execute(movieID: Int) async throws -> ViewerMovieState? {
        let outcome = outcomes[index]
        index += 1
        switch outcome {
            case let .state(state):
                return state
            case let .gated(gate, state):
                await gate.wait()
                return state
            case .failure:
                throw FeedbackTestError.failed
        }
    }
}

enum FeedbackUpdateOutcome: Sendable {
    case change(ViewerMovieStateChange)
    case gated(FeedbackOperationGate, ViewerMovieStateChange)
    case gatedCancellation(FeedbackOperationGate)
    case failure
}

actor RecordingFeedbackUpdate: UpdateViewerMovieStateUseCase {
    let outcomes: [FeedbackUpdateOutcome]
    private var index = 0
    private(set) var transitions: [ViewerMovieStateTransition] = []
    private(set) var metadata: [MovieFeedbackMetadata] = []

    init(outcomes: [FeedbackUpdateOutcome]) {
        self.outcomes = outcomes
    }

    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange {
        transitions.append(transition)
        self.metadata.append(metadata)
        let outcome = outcomes[index]
        index += 1
        switch outcome {
            case let .change(change):
                return change
            case let .gated(gate, change):
                await gate.wait()
                return change
            case let .gatedCancellation(gate):
                await gate.wait()
                throw CancellationError()
            case .failure:
                throw FeedbackTestError.failed
        }
    }

    func waitForCallCount(_ count: Int) async {
        for _ in 0 ..< 200 {
            if transitions.count == count {
                return
            }
            await Task.yield()
        }
    }
}

actor FeedbackOperationGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }
}

struct ImmediateFeedbackMovieDetailUseCase: GetMovieDetailUseCase {
    func execute(
        id: Int,
        policy: CachePolicy
    ) throws -> CacheResult<MovieDetailSnapshot> {
        CacheResult(value: .feedbackFixture, isStale: false)
    }
}

struct FailingMovieDetailUseCase: GetMovieDetailUseCase {
    func execute(
        id: Int,
        policy: CachePolicy
    ) throws -> CacheResult<MovieDetailSnapshot> {
        throw FeedbackTestError.failed
    }
}

struct FeedbackUnknownAvailability: CheckMovieAvailabilityUseCase {
    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) throws -> AvailabilityOutcome {
        .unknown(reason: .regionalEvidenceMissing)
    }
}

struct FeedbackUnavailablePlaybackOptions: PreparePlaybackOptionsUseCase {
    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) throws -> PlaybackOptionsPreparation {
        .unavailable
    }
}

enum FeedbackTestError: Error {
    case failed
}

private extension MovieDetailSnapshot {
    static let feedbackFixture = MovieDetailSnapshot(
        movie: Movie(
            id: 42,
            title: "Detail title",
            originalTitle: "Detail title",
            overview: "Overview",
            releaseDate: nil,
            runtime: 120,
            rating: 8,
            voteCount: 100,
            posterPath: "/detail.jpg",
            backdropPath: nil,
            genres: [],
            tagline: nil
        ),
        similar: [],
        director: nil,
        topCast: [],
        isSimilarUnavailable: false,
        isCreditsUnavailable: false,
        asOf: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
