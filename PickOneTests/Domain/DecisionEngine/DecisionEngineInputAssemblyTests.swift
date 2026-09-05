import Foundation
@testable import PickOne
import Testing

@Suite("Decision Engine input assembly")
struct DecisionEngineInputAssemblyTests {
    @Test("assembles Taste, exclusions, and Watchlist intent only from Viewer Movie State")
    func assemblesViewerMovieStateSnapshot() async throws {
        let trusted = try trustedState(
            reactions: [10: .loveIt, 11: .likeIt, 12: .itWasOkay, 13: .didNotLikeIt],
            watchedMovieIDs: [20],
            notInterestedMovieIDs: [25],
            savedMovieIDs: [30]
        )
        let candidates = try [20, 25, 30, 40].map(candidateSeed)
        let sut = AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(candidates: candidates),
            movieRepository: InputAssemblyMovieRepository(
                movies: hydrationMovies(for: trusted.reactions)
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                evidenceByMovieID: [
                    30: verifiedEvidence(movieID: 30, providerID: 119),
                    40: verifiedEvidence(movieID: 40, providerID: 8),
                ]
            )
        )

        let snapshot = try await sut.execute(
            trustedState: trusted,
            currentCycleShownMovieIDs: [40]
        )

        #expect(snapshot.trustedState == trusted)
        #expect(snapshot.input.profile.evidence.map(\.movieID) == [10, 11, 12, 13])
        #expect(snapshot.input.recommendationExcludedMovieIDs == [10, 11, 12, 13, 20, 25])
        #expect(snapshot.input.savedUnwatchedMovieIDs == [30])
        #expect(snapshot.input.currentCycleShownMovieIDs == [40])
        #expect(snapshot.candidates.map(\.seed.movieID) == [30])
        #expect(snapshot.input.candidates == snapshot.candidates.map(\.decisionCandidate))
    }

    @Test("Not interested excludes its title without becoming Taste evidence")
    func notInterestedIsExclusionOnly() async throws {
        let trusted = try trustedState(
            reactions: [10: .loveIt],
            notInterestedMovieIDs: [20]
        )
        let availability = InputAssemblyAvailabilityRepository(
            evidenceByMovieID: [30: verifiedEvidence(movieID: 30, providerID: 8)]
        )
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: [20, 30].map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(
                movies: hydrationMovies(for: trusted.reactions)
            ),
            availabilityRepository: availability
        )

        let snapshot = try await sut.execute(
            trustedState: trusted,
            currentCycleShownMovieIDs: []
        )

        #expect(snapshot.input.profile.evidence.map(\.movieID) == [10])
        #expect(snapshot.input.recommendationExcludedMovieIDs.contains(20))
        #expect(snapshot.candidates.map(\.seed.movieID) == [30])
        #expect(await availability.requestedMovieIDs == [30])
    }

    @Test("an entirely locally excluded pool succeeds as empty")
    func entirelyExcludedPoolSucceedsAsEmpty() async throws {
        let trusted = try trustedState(watchedMovieIDs: [20])
        let availability = InputAssemblyAvailabilityRepository(
            failingMovieIDs: [20, 30]
        )
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: [20, 30].map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: availability
        )

        let snapshot = try await sut.execute(
            trustedState: trusted,
            currentCycleShownMovieIDs: [30]
        )

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.input.candidates.isEmpty)
        #expect(await availability.requestedMovieIDs.isEmpty)
    }

    @Test("mixed pools verify remaining candidates in recall order")
    func mixedPoolsPreserveRemainingRecallOrder() async throws {
        let trusted = try trustedState(watchedMovieIDs: [20])
        let remainingMovieIDs = [50, 40, 60]
        let availability = InputAssemblyAvailabilityRepository(
            evidenceByMovieID: Dictionary(
                uniqueKeysWithValues: remainingMovieIDs.map {
                    ($0, verifiedEvidence(movieID: $0, providerID: 8))
                }
            )
        )
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: [50, 40, 20, 30, 60].map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: availability
        )

        let snapshot = try await sut.execute(
            trustedState: trusted,
            currentCycleShownMovieIDs: [30]
        )

        #expect(snapshot.candidates.map(\.seed.movieID) == remainingMovieIDs)
        #expect(await Set(availability.requestedMovieIDs) == Set(remainingMovieIDs))
    }

    @Test("one availability failure remains unknown while usable candidates survive")
    func availabilityFailureIsPartial() async throws {
        let trusted = try trustedState()
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: [30, 40].map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                evidenceByMovieID: [40: verifiedEvidence(movieID: 40, providerID: 8)],
                failingMovieIDs: [30]
            )
        )

        let snapshot = try await sut.execute(
            trustedState: trusted,
            currentCycleShownMovieIDs: []
        )

        #expect(snapshot.candidates.map(\.availability) == [.unknown, .eligible])
    }

    @Test("source-wide availability failure is not reported as honest empty")
    func sourceWideAvailabilityFailureBlocksAssembly() async throws {
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: [30, 40].map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                failingMovieIDs: [30, 40]
            )
        )

        let prepared = try await sut.prepare(trustedState: trustedState())
        let batch = try await sut.recallAndEnrich(
            pages: RecommendationSearchPolicy.accepted.normalPageRange,
            prepared: prepared,
            excludingMovieIDs: [],
            alreadyRecalledMovieIDs: []
        )

        #expect(batch.hasUnresolvedAvailability)
        #expect(batch.candidates.map(\.availabilityOutcome) == [
            .unknown(reason: .verificationFailed),
            .unknown(reason: .verificationFailed),
        ])
    }

    @Test("availability verification never exceeds eight concurrent requests")
    func boundsAvailabilityConcurrency() async throws {
        let candidateIDs = Array(30 ... 38)
        let availability = InputAssemblyAvailabilityRepository(
            evidenceByMovieID: Dictionary(uniqueKeysWithValues: candidateIDs.map {
                ($0, verifiedEvidence(movieID: $0, providerID: 8))
            }),
            delay: .milliseconds(20)
        )
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: candidateIDs.map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: availability
        )

        let snapshot = try await sut.execute(
            trustedState: trustedState(),
            currentCycleShownMovieIDs: []
        )

        #expect(snapshot.candidates.count == 9)
        #expect(await availability.maximumActiveRequestCount <= 8)
        #expect(await availability.requestCount == 9)
    }

    @Test("cancellation stops bounded availability scheduling and propagates")
    func cancellationStopsAvailabilityScheduling() async throws {
        let candidateIDs = Array(30 ... 41)
        let availability = InputAssemblyAvailabilityRepository(
            suspendsUntilCancelled: true
        )
        let sut = try AssembleDecisionEngineInput(
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: candidateIDs.map(candidateSeed)
            ),
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: availability
        )
        let assembly = Task {
            try await sut.execute(
                trustedState: trustedState(),
                currentCycleShownMovieIDs: []
            )
        }

        await availability.waitUntilRequestCount(8)
        assembly.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await assembly.value
        }
        let requestedMovieIDs = await availability.requestedMovieIDs
        #expect(requestedMovieIDs.count == 8)
        #expect(Set(requestedMovieIDs) == Set(candidateIDs.prefix(8)))
    }

    @Test("Taste hydration failure prevents candidate recall")
    func tasteHydrationFailureBlocksAssembly() async throws {
        let trusted = try trustedState(reactions: [10: .loveIt, 20: .likeIt])
        let candidates = InputAssemblyCandidateRepository(candidates: [])
        let sut = AssembleDecisionEngineInput(
            candidateRepository: candidates,
            movieRepository: InputAssemblyMovieRepository(
                movies: hydrationMovies(for: trusted.reactions),
                failingMovieIDs: [10]
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository()
        )

        await #expect(
            throws: DecisionEngineInputAssemblyError.tasteHydrationFailed(movieID: 10)
        ) {
            _ = try await sut.execute(
                trustedState: trusted,
                currentCycleShownMovieIDs: []
            )
        }
        #expect(await candidates.requestedPages.isEmpty)
    }
}

private enum InputAssemblyTestError: Error { case failed }

private actor InputAssemblyCandidateRepository: DecisionCandidateRepository {
    private let candidates: [DecisionCandidateSeed]
    private(set) var requestedPages: [Int] = []

    init(candidates: [DecisionCandidateSeed]) {
        self.candidates = candidates
    }

    func discoverPage(
        _ page: Int,
        context _: DecisionCandidateContext
    ) async throws -> [DecisionCandidateSeed] {
        requestedPages.append(page)
        return page == 1 ? candidates : []
    }
}

private actor InputAssemblyMovieRepository: MovieRepository {
    private let movies: [Int: Movie]
    private let failingMovieIDs: Set<Int>

    init(movies: [Int: Movie], failingMovieIDs: Set<Int> = []) {
        self.movies = movies
        self.failingMovieIDs = failingMovieIDs
    }

    func getMovieDetail(id: Int, policy _: CachePolicy) async throws -> CacheResult<Movie> {
        guard !failingMovieIDs.contains(id), let movie = movies[id] else {
            throw InputAssemblyTestError.failed
        }
        return CacheResult(value: movie, isStale: false)
    }

    func getTopRated(page _: Int, policy _: CachePolicy) async throws -> CacheResult<MoviePage> {
        throw InputAssemblyTestError.failed
    }

    func getSimilarMovies(
        id _: Int,
        page _: Int,
        policy _: CachePolicy
    ) async throws -> CacheResult<MoviePage> {
        throw InputAssemblyTestError.failed
    }

    func getCredits(id _: Int, policy _: CachePolicy) async throws -> CacheResult<Credits> {
        throw InputAssemblyTestError.failed
    }

    func searchMovies(query _: String, page _: Int) async throws -> MoviePage {
        throw InputAssemblyTestError.failed
    }
}

private actor InputAssemblyAvailabilityRepository: AvailabilityRepository {
    private let evidenceByMovieID: [Int: VerifiedAvailabilityEvidence]
    private let failingMovieIDs: Set<Int>
    private let delay: Duration?
    private let suspendsUntilCancelled: Bool
    private(set) var requestCount = 0
    private(set) var maximumActiveRequestCount = 0
    private(set) var requestedMovieIDs: [Int] = []
    private var activeRequestCount = 0
    private var requestCountWaiters: [RequestCountWaiter] = []

    init(
        evidenceByMovieID: [Int: VerifiedAvailabilityEvidence] = [:],
        failingMovieIDs: Set<Int> = [],
        delay: Duration? = nil,
        suspendsUntilCancelled: Bool = false
    ) {
        self.evidenceByMovieID = evidenceByMovieID
        self.failingMovieIDs = failingMovieIDs
        self.delay = delay
        self.suspendsUntilCancelled = suspendsUntilCancelled
    }

    func getVerifiedEvidence(
        movieID: Int,
        region _: ViewingRegion,
        policy _: AvailabilityFetchPolicy
    ) async throws -> VerifiedAvailabilityEvidence? {
        requestCount += 1
        requestedMovieIDs.append(movieID)
        activeRequestCount += 1
        maximumActiveRequestCount = max(maximumActiveRequestCount, activeRequestCount)
        resumeSatisfiedRequestCountWaiters()
        defer { activeRequestCount -= 1 }
        if suspendsUntilCancelled {
            try await Task.sleep(for: .seconds(60))
        }
        if let delay {
            try await Task.sleep(for: delay)
        }
        guard !failingMovieIDs.contains(movieID) else {
            throw InputAssemblyTestError.failed
        }
        return evidenceByMovieID[movieID]
    }

    func waitUntilRequestCount(_ expectedCount: Int) async {
        guard requestCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters.append(RequestCountWaiter(
                expectedCount: expectedCount,
                continuation: continuation
            ))
        }
    }

    private func resumeSatisfiedRequestCountWaiters() {
        var pending: [RequestCountWaiter] = []
        for waiter in requestCountWaiters {
            if requestCount >= waiter.expectedCount {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        requestCountWaiters = pending
    }
}

private struct RequestCountWaiter {
    let expectedCount: Int
    let continuation: CheckedContinuation<Void, Never>
}

private func trustedState(
    reactions: [Int: MovieReaction] = [:],
    watchedMovieIDs: Set<Int> = [],
    notInterestedMovieIDs: Set<Int> = [],
    savedMovieIDs: Set<Int> = []
) throws -> TrustedDecisionState {
    let metadata = try MovieFeedbackMetadata(
        title: "Movie",
        releaseYear: 2010,
        posterPath: nil
    )
    var states = try reactions.map { movieID, reaction in
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: metadata,
            watchState: .watched,
            preference: .reaction(reaction),
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }
    states += try watchedMovieIDs.subtracting(reactions.keys).map { movieID in
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: metadata,
            watchState: .watched,
            preference: nil,
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }
    states += try notInterestedMovieIDs.map { movieID in
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: metadata,
            watchState: .unwatched,
            preference: .notInterested,
            watchlistIntent: nil,
            stateChangedAt: .distantPast
        )
    }
    states += try savedMovieIDs.map { movieID in
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: metadata,
            watchState: .unwatched,
            preference: nil,
            watchlistIntent: WatchlistIntent(addedAt: .distantPast),
            stateChangedAt: .distantPast
        )
    }
    return try TrustedDecisionState(
        profile: ViewerProfile(
            profileSchemaVersion: ViewerProfile.currentSchemaVersion,
            catalogID: .spainHouseholdV1,
            region: .spain,
            selectedServices: [.netflix],
            reactions: [:]
        ),
        viewerMovieState: ViewerMovieStateSnapshot(
            id: ViewerStateSnapshotID(rawValue: UUID()),
            states: states
        )
    )
}

private func candidateSeed(id: Int) throws -> DecisionCandidateSeed {
    try #require(DecisionCandidateSeed(
        movieID: id,
        localizedTitle: "Movie \(id)",
        posterPath: nil,
        backdropPath: nil,
        genres: [DecisionGenre(id: 18, name: "Drama")],
        releaseYear: 2010,
        voteAverage: 9,
        voteCount: 20000
    ))
}

private func hydrationMovies(for reactions: [Int: MovieReaction]) -> [Int: Movie] {
    Dictionary(uniqueKeysWithValues: reactions.keys.map { movieID in
        (
            movieID,
            Movie(
                id: movieID,
                title: "Anchor \(movieID)",
                originalTitle: "Anchor \(movieID)",
                overview: "",
                releaseDate: Date(timeIntervalSince1970: 1_262_304_000),
                runtime: 100,
                rating: 8,
                voteCount: 1000,
                posterPath: nil,
                backdropPath: nil,
                genres: [Genre(id: 18, name: "Drama")],
                tagline: nil
            )
        )
    })
}

private func verifiedEvidence(
    movieID: Int,
    providerID: Int
) -> VerifiedAvailabilityEvidence {
    VerifiedAvailabilityEvidence(
        regionalEvidence: RegionalAvailabilityEvidence(
            movieID: movieID,
            region: .spain,
            watchURL: "https://www.themoviedb.org/movie/\(movieID)/watch",
            flatrate: [ProviderOfferEvidence(
                providerID: providerID,
                sourceName: "Provider",
                logoPath: nil
            )],
            rent: [],
            buy: [],
            ads: [],
            free: []
        ),
        verifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
