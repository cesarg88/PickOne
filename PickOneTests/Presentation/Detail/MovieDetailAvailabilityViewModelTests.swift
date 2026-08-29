import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("MovieDetail availability tests", .serialized)
struct MovieDetailAvailabilityViewModelTests {
    @Test("detail renders while availability is still loading")
    func detailRendersBeforeAvailability() async {
        let gate = AsyncAvailabilityGate()
        let availability = SequenceAvailabilityUseCase(
            steps: [.gated(gate, eligibleOutcome())]
        )
        let sut = makeSUT(
            detail: ImmediateMovieDetailUseCase(),
            availability: availability
        )

        let load = Task { await sut.load() }
        await yieldUntil {
            if case .loaded = sut.state { return true }
            return false
        }

        guard case .loaded = sut.state else {
            Issue.record("Expected loaded detail")
            await gate.open()
            await load.value
            return
        }
        #expect(sut.availabilityState == .loading)

        await gate.open()
        await load.value
    }

    @Test("availability resolves while detail is still loading")
    func availabilityRendersBeforeDetail() async {
        let gate = AsyncAvailabilityGate()
        let detail = GatedMovieDetailUseCase(gate: gate)
        let sut = makeSUT(
            detail: detail,
            availability: SequenceAvailabilityUseCase(
                steps: [.outcome(eligibleOutcome())]
            )
        )

        let load = Task { await sut.load() }
        await yieldUntil {
            if case .eligible = sut.availabilityState { return true }
            return false
        }

        guard case .eligible = sut.availabilityState else {
            Issue.record("Expected eligible availability")
            await gate.open()
            await load.value
            return
        }
        #expect(sut.state == .loading)

        await gate.open()
        await load.value
    }

    @Test("availability failure does not replace loaded detail")
    func availabilityFailureIsIndependent() async {
        let sut = makeSUT(
            detail: ImmediateMovieDetailUseCase(),
            availability: SequenceAvailabilityUseCase(steps: [.failure])
        )

        await sut.load()

        guard case .loaded = sut.state else {
            Issue.record("Expected loaded detail")
            return
        }
        #expect(sut.availabilityState == .unknown)
    }

    @Test("retry starts a new availability attempt")
    func retryStartsNewAttempt() async {
        let availability = SequenceAvailabilityUseCase(
            steps: [
                .outcome(.unknown(reason: .verificationFailed)),
                .outcome(eligibleOutcome()),
            ]
        )
        let sut = makeSUT(
            detail: ImmediateMovieDetailUseCase(),
            availability: availability
        )

        await sut.load()
        #expect(sut.availabilityState == .unknown)
        await sut.load()

        guard case .eligible = sut.availabilityState else {
            Issue.record("Expected eligible availability after retry")
            return
        }
        #expect(await availability.callCount == 2)
    }

    @Test("cancellation publishes no completed availability outcome")
    func cancellationDoesNotPublishOutcome() async {
        let gate = AsyncAvailabilityGate()
        let sut = makeSUT(
            detail: ImmediateMovieDetailUseCase(),
            availability: SequenceAvailabilityUseCase(
                steps: [.gated(gate, eligibleOutcome())]
            )
        )

        let load = Task { await sut.load() }
        await yieldUntil {
            if case .loaded = sut.state { return true }
            return false
        }
        load.cancel()
        await gate.open()
        await load.value

        #expect(sut.availabilityState == .loading)
    }

    @Test("late superseded availability cannot replace newer state")
    func staleResponseIsIgnored() async {
        let gate = AsyncAvailabilityGate()
        let availability = SequenceAvailabilityUseCase(
            steps: [
                .gated(gate, eligibleOutcome()),
                .outcome(.ineligible(
                    evidence: AvailabilityTestFixtures.verifiedEvidence()
                )),
            ]
        )
        let sut = makeSUT(
            detail: ImmediateMovieDetailUseCase(),
            availability: availability
        )

        let firstLoad = Task { await sut.load() }
        await yieldUntil { await availability.callCount == 1 }
        await sut.load()
        #expect(sut.availabilityState == .ineligible)

        await gate.open()
        await firstLoad.value

        #expect(sut.availabilityState == .ineligible)
    }

    @Test("handoff revalidation can publish a replacement state")
    func handoffPublishesReplacementState() async throws {
        var changes: [DecisionEligibilityChange] = []
        let updated = AvailabilityOutcome.ineligible(
            evidence: AvailabilityTestFixtures.verifiedEvidence()
        )
        let sut = makeSUT(
            detail: ImmediateMovieDetailUseCase(),
            availability: SequenceAvailabilityUseCase(
                steps: [.outcome(eligibleOutcome())]
            ),
            prepare: StubPreparePlaybackOptions(
                result: .updatedOutcome(updated)
            ),
            eligibilityDidChange: { changes.append($0) }
        )
        await sut.load()

        let url = await sut.preparePlaybackOptions()

        #expect(url == nil)
        #expect(sut.availabilityState == .ineligible)
        let expectedChange = try #require(
            DecisionEligibilityChange(movieID: 42, cause: .availability)
        )
        #expect(changes == [expectedChange])
    }

    @Test("nested detail dependencies preserve the Viewer State callback")
    func nestedDetailDependenciesPreserveCallback() async throws {
        let snapshotID = ViewerStateSnapshotID(rawValue: UUID())
        var changes: [DecisionViewerStateChange] = []
        let dependencies = MovieDetailNavigationDependencies(
            getMovieDetail: ImmediateMovieDetailUseCase(),
            getViewerMovieState: NoOpGetViewerMovieState(),
            updateViewerMovieState: FixedFeedbackUpdate(change: ViewerMovieStateChange(
                state: nil,
                impact: .watchlistIntentChanged,
                snapshotID: snapshotID
            )),
            checkAvailability: SequenceAvailabilityUseCase(
                steps: [.outcome(eligibleOutcome())]
            ),
            preparePlaybackOptions: StubPreparePlaybackOptions(result: .unavailable),
            viewerStateDidChange: { changes.append($0) },
            eligibilityDidChange: { _ in }
        )
        let sut = dependencies.makeViewModel(movieID: 42)

        await sut.load()
        await sut.toggleWatchlist()

        let expectedChange = try #require(DecisionViewerStateChange(
            movieID: 42,
            impact: .watchlistIntentChanged,
            snapshotID: snapshotID
        ))
        #expect(changes == [expectedChange])
    }

    private func makeSUT(
        detail: GetMovieDetailUseCase,
        availability: CheckMovieAvailabilityUseCase,
        prepare: PreparePlaybackOptionsUseCase = StubPreparePlaybackOptions(
            result: .unavailable
        ),
        eligibilityDidChange: @escaping @MainActor (DecisionEligibilityChange) -> Void = { _ in }
    ) -> MovieDetailViewModel {
        MovieDetailViewModel(
            movieId: 42,
            getMovieDetail: detail,
            getViewerMovieState: NoOpGetViewerMovieState(),
            updateViewerMovieState: NoOpUpdateViewerMovieState(),
            checkAvailability: availability,
            preparePlaybackOptions: prepare,
            eligibilityDidChange: eligibilityDidChange
        )
    }

    private func yieldUntil(
        _ predicate: @MainActor () async -> Bool
    ) async {
        for _ in 0 ..< 200 {
            if await predicate() {
                return
            }
            await Task.yield()
        }
    }

    private func eligibleOutcome() -> AvailabilityOutcome {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            flatrate: [AvailabilityTestFixtures.offer(id: 8)]
        )
        return .eligible(
            providers: [
                EligibleStreamingProvider(
                    id: 8,
                    name: "Netflix",
                    logoPath: "/netflix.png",
                    productOrder: 1
                ),
            ],
            evidence: evidence
        )
    }
}

private struct NoOpGetViewerMovieState: GetViewerMovieStateUseCase {
    func execute(movieID: Int) -> ViewerMovieState? {
        nil
    }
}

private struct NoOpUpdateViewerMovieState: UpdateViewerMovieStateUseCase {
    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) -> ViewerMovieStateChange {
        ViewerMovieStateChange(
            state: nil,
            impact: .none,
            snapshotID: ViewerStateSnapshotID(rawValue: UUID())
        )
    }
}

private struct FixedFeedbackUpdate: UpdateViewerMovieStateUseCase {
    let change: ViewerMovieStateChange

    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) -> ViewerMovieStateChange {
        change
    }
}

private actor AsyncAvailabilityGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }
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

private actor SequenceAvailabilityUseCase: CheckMovieAvailabilityUseCase {
    enum Step: Sendable {
        case outcome(AvailabilityOutcome)
        case gated(AsyncAvailabilityGate, AvailabilityOutcome)
        case failure
    }

    private let steps: [Step]
    private var index = 0
    private(set) var callCount = 0

    init(steps: [Step]) {
        self.steps = steps
    }

    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) async throws -> AvailabilityOutcome {
        let step = steps[index]
        index += 1
        callCount += 1
        switch step {
            case let .outcome(outcome):
                return outcome
            case let .gated(gate, outcome):
                await gate.wait()
                try Task.checkCancellation()
                return outcome
            case .failure:
                throw MovieDetailAvailabilityTestError.failed
        }
    }
}

private actor ImmediateMovieDetailUseCase: GetMovieDetailUseCase {
    func execute(
        id: Int,
        policy: CachePolicy
    ) async throws -> CacheResult<MovieDetailSnapshot> {
        CacheResult(value: movieDetailSnapshot, isStale: false)
    }
}

private actor GatedMovieDetailUseCase: GetMovieDetailUseCase {
    private let gate: AsyncAvailabilityGate

    init(gate: AsyncAvailabilityGate) {
        self.gate = gate
    }

    func execute(
        id: Int,
        policy: CachePolicy
    ) async throws -> CacheResult<MovieDetailSnapshot> {
        await gate.wait()
        try Task.checkCancellation()
        return CacheResult(value: movieDetailSnapshot, isStale: false)
    }
}

private struct StubPreparePlaybackOptions: PreparePlaybackOptionsUseCase {
    let result: PlaybackOptionsPreparation

    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) async throws -> PlaybackOptionsPreparation {
        result
    }
}

private enum MovieDetailAvailabilityTestError: Error {
    case failed
}

private let movieDetailSnapshot = MovieDetailSnapshot(
    movie: Movie(
        id: 42,
        title: "Movie",
        originalTitle: "Movie",
        overview: "Overview",
        releaseDate: nil,
        runtime: 100,
        rating: 7,
        voteCount: 100,
        posterPath: nil,
        backdropPath: nil,
        genres: [],
        tagline: nil
    ),
    similar: [],
    director: nil,
    topCast: [],
    isSimilarUnavailable: false,
    isCreditsUnavailable: false,
    asOf: AvailabilityTestFixtures.now
)
