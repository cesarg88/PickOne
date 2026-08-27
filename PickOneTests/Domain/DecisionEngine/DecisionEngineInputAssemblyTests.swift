import Foundation
@testable import PickOne
import Testing

@Suite("Decision Engine input assembly")
struct DecisionEngineInputAssemblyTests {
    @Test("assembles profile, Watchlist, calibration, recall, and availability")
    func assemblesTrustedSnapshot() async throws {
        let profileRepository = try await makeCompletedProfileRepository()
        let watched = watchlistItem(id: 20, isWatched: true)
        let saved = watchlistItem(id: 30, isWatched: false)
        let candidates = try [
            candidateSeed(id: 20),
            candidateSeed(id: 30),
            candidateSeed(id: 40),
        ]
        let sut = AssembleDecisionEngineInput(
            viewerProfileRepository: profileRepository,
            watchlistRepository: InputAssemblyWatchlistRepository(items: [watched, saved]),
            candidateRepository: InputAssemblyCandidateRepository(candidates: candidates),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: ViewerProfileTestFixtures.reactions(count: 8))
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                evidenceByMovieID: [
                    20: verifiedEvidence(movieID: 20, providerID: 8),
                    30: verifiedEvidence(movieID: 30, providerID: 119),
                    40: verifiedEvidence(movieID: 40, providerID: 8),
                ]
            )
        )

        let snapshot = try await sut.execute(currentCycleShownMovieIDs: [40])

        #expect(snapshot.profile.selectedServices == [.netflix])
        #expect(snapshot.watchlistItems == [watched, saved])
        #expect(snapshot.input.profile.evidence.count == 8)
        #expect(snapshot.input.watchlistWatchedMovieIDs == [20])
        #expect(snapshot.input.savedUnwatchedMovieIDs == [30])
        #expect(snapshot.input.currentCycleShownMovieIDs == [40])
        #expect(snapshot.candidates.map(\.seed.movieID) == [30])
        #expect(snapshot.candidates.map(\.availability) == [.ineligible])
        #expect(snapshot.input.candidates == snapshot.candidates.map(\.decisionCandidate))
    }

    @Test("local exclusions never reach availability verification")
    func localExclusionsSkipAvailability() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(count: 8)
        let calibrationMovieID = try #require(reactions.keys.min())
        let watchlistWatchedMovieID = 20
        let shownMovieID = 30
        let remainingMovieID = 40
        let candidateIDs = [
            calibrationMovieID,
            watchlistWatchedMovieID,
            shownMovieID,
            remainingMovieID,
        ]
        let availabilityRepository = InputAssemblyAvailabilityRepository(
            evidenceByMovieID: [
                remainingMovieID: verifiedEvidence(
                    movieID: remainingMovieID,
                    providerID: 8
                ),
            ]
        )
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(
                items: [watchlistItem(id: watchlistWatchedMovieID, isWatched: true)]
            ),
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: candidateIDs.map { try candidateSeed(id: $0) }
            ),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: reactions)
            ),
            availabilityRepository: availabilityRepository
        )

        let snapshot = try await sut.execute(
            currentCycleShownMovieIDs: [shownMovieID]
        )

        #expect(snapshot.candidates.map(\.seed.movieID) == [remainingMovieID])
        #expect(await availabilityRepository.requestedMovieIDs == [remainingMovieID])
    }

    @Test("an entirely locally excluded pool succeeds as empty")
    func entirelyExcludedPoolSucceedsAsEmpty() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(count: 8)
        let calibrationMovieID = try #require(reactions.keys.min())
        let watchlistWatchedMovieID = 20
        let shownMovieID = 30
        let availabilityRepository = InputAssemblyAvailabilityRepository(
            failingMovieIDs: [calibrationMovieID, watchlistWatchedMovieID, shownMovieID]
        )
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(
                items: [watchlistItem(id: watchlistWatchedMovieID, isWatched: true)]
            ),
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: [
                    candidateSeed(id: calibrationMovieID),
                    candidateSeed(id: watchlistWatchedMovieID),
                    candidateSeed(id: shownMovieID),
                ]
            ),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: reactions)
            ),
            availabilityRepository: availabilityRepository
        )

        let snapshot = try await sut.execute(
            currentCycleShownMovieIDs: [shownMovieID]
        )

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.input.candidates.isEmpty)
        #expect(await availabilityRepository.requestedMovieIDs.isEmpty)
    }

    @Test("mixed pools verify remaining candidates in recall order")
    func mixedPoolsPreserveRemainingRecallOrder() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(count: 8)
        let calibrationMovieID = try #require(reactions.keys.min())
        let watchedMovieID = 20
        let shownMovieID = 30
        let remainingMovieIDs = [50, 40, 60]
        let recalledMovieIDs = [
            50,
            calibrationMovieID,
            40,
            watchedMovieID,
            shownMovieID,
            60,
        ]
        let availabilityRepository = InputAssemblyAvailabilityRepository(
            evidenceByMovieID: Dictionary(
                uniqueKeysWithValues: remainingMovieIDs.map {
                    ($0, verifiedEvidence(movieID: $0, providerID: 8))
                }
            )
        )
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(
                items: [watchlistItem(id: watchedMovieID, isWatched: true)]
            ),
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: recalledMovieIDs.map { try candidateSeed(id: $0) }
            ),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: reactions)
            ),
            availabilityRepository: availabilityRepository
        )

        let snapshot = try await sut.execute(
            currentCycleShownMovieIDs: [shownMovieID]
        )

        #expect(snapshot.candidates.map(\.seed.movieID) == remainingMovieIDs)
        #expect(await Set(availabilityRepository.requestedMovieIDs) == Set(remainingMovieIDs))
    }

    @Test("Watchlist corruption blocks assembly instead of becoming empty")
    func watchlistFailureBlocksAssembly() async throws {
        let candidateRepository = InputAssemblyCandidateRepository(candidates: [])
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(error: .unreadable),
            candidateRepository: candidateRepository,
            movieRepository: InputAssemblyMovieRepository(movies: [:]),
            availabilityRepository: InputAssemblyAvailabilityRepository()
        )

        await #expect(throws: DecisionEngineInputAssemblyError.watchlistUnavailable) {
            _ = try await sut.execute(currentCycleShownMovieIDs: [])
        }
        #expect(await candidateRepository.requestedPages.isEmpty)
    }

    @Test("one availability failure remains unknown while usable candidates survive")
    func availabilityFailureIsPartial() async throws {
        let candidates = try [candidateSeed(id: 30), candidateSeed(id: 40)]
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(),
            candidateRepository: InputAssemblyCandidateRepository(candidates: candidates),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: ViewerProfileTestFixtures.reactions(count: 8))
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                evidenceByMovieID: [40: verifiedEvidence(movieID: 40, providerID: 8)],
                failingMovieIDs: [30]
            )
        )

        let snapshot = try await sut.execute(currentCycleShownMovieIDs: [])

        #expect(snapshot.candidates.map(\.availability) == [.unknown, .eligible])
    }

    @Test("source-wide availability failure is not reported as honest empty")
    func sourceWideAvailabilityFailureBlocksAssembly() async throws {
        let candidates = try [candidateSeed(id: 30), candidateSeed(id: 40)]
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(),
            candidateRepository: InputAssemblyCandidateRepository(candidates: candidates),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: ViewerProfileTestFixtures.reactions(count: 8))
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                failingMovieIDs: [30, 40]
            )
        )

        await #expect(
            throws: DecisionEngineInputAssemblyError.availabilitySourceUnavailable
        ) {
            _ = try await sut.execute(currentCycleShownMovieIDs: [])
        }
    }

    @Test("availability verification never exceeds eight concurrent requests")
    func boundsAvailabilityConcurrency() async throws {
        let candidateIDs = Array(30 ... 38)
        let candidates = try candidateIDs.map { try candidateSeed(id: $0) }
        let evidence = Dictionary(
            uniqueKeysWithValues: candidateIDs.map {
                ($0, verifiedEvidence(movieID: $0, providerID: 8))
            }
        )
        let availabilityRepository = InputAssemblyAvailabilityRepository(
            evidenceByMovieID: evidence,
            delay: .milliseconds(20)
        )
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(),
            candidateRepository: InputAssemblyCandidateRepository(candidates: candidates),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: ViewerProfileTestFixtures.reactions(count: 8))
            ),
            availabilityRepository: availabilityRepository
        )

        let snapshot = try await sut.execute(currentCycleShownMovieIDs: [])

        #expect(snapshot.candidates.count == 9)
        #expect(await availabilityRepository.maximumActiveRequestCount <= 8)
        #expect(await availabilityRepository.requestCount == 9)
    }

    @Test("cancellation stops bounded availability scheduling and propagates")
    func cancellationStopsAvailabilityScheduling() async throws {
        let candidateIDs = Array(30 ... 41)
        let availabilityRepository = InputAssemblyAvailabilityRepository(
            suspendsUntilCancelled: true
        )
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(),
            candidateRepository: InputAssemblyCandidateRepository(
                candidates: candidateIDs.map { try candidateSeed(id: $0) }
            ),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: ViewerProfileTestFixtures.reactions(count: 8))
            ),
            availabilityRepository: availabilityRepository
        )
        let assembly = Task {
            try await sut.execute(currentCycleShownMovieIDs: [])
        }

        await availabilityRepository.waitUntilRequestCount(8)
        assembly.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await assembly.value
        }
        let requestedMovieIDs = await availabilityRepository.requestedMovieIDs
        #expect(requestedMovieIDs.count == 8)
        #expect(Set(requestedMovieIDs) == Set(candidateIDs.prefix(8)))
    }

    @Test("calibration hydration failure blocks an incomplete taste profile")
    func calibrationHydrationFailureBlocksAssembly() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(count: 8)
        let failedMovieID = try #require(reactions.keys.min())
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(),
            candidateRepository: InputAssemblyCandidateRepository(candidates: []),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: reactions),
                failingMovieIDs: [failedMovieID]
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository()
        )

        await #expect(
            throws: DecisionEngineInputAssemblyError.calibrationHydrationFailed(
                movieID: failedMovieID
            )
        ) {
            _ = try await sut.execute(currentCycleShownMovieIDs: [])
        }
    }

    @Test("assembled watched exclusions are honored by the pure selector")
    func assembledExclusionsReachSelector() async throws {
        let reactions = ViewerProfileTestFixtures.reactions(count: 8)
        let calibrationMovieID = try #require(reactions.keys.min())
        let watchedMovieID = 20
        let candidateIDs = [calibrationMovieID, watchedMovieID, 30]
        let candidates = try candidateIDs.map { try candidateSeed(id: $0) }
        let evidence = Dictionary(
            uniqueKeysWithValues: candidateIDs.map {
                ($0, verifiedEvidence(movieID: $0, providerID: 8))
            }
        )
        let sut = try await AssembleDecisionEngineInput(
            viewerProfileRepository: makeCompletedProfileRepository(),
            watchlistRepository: InputAssemblyWatchlistRepository(
                items: [watchlistItem(id: watchedMovieID, isWatched: true)]
            ),
            candidateRepository: InputAssemblyCandidateRepository(candidates: candidates),
            movieRepository: InputAssemblyMovieRepository(
                movies: calibrationMovies(for: reactions)
            ),
            availabilityRepository: InputAssemblyAvailabilityRepository(
                evidenceByMovieID: evidence
            )
        )

        let snapshot = try await sut.execute(currentCycleShownMovieIDs: [])
        let selection = P1DecisionEngine().select(from: snapshot.input)

        #expect(selection.recommendations.map(\.candidate.movieID) == [30])
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
        context: DecisionCandidateContext
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

    func getMovieDetail(id: Int, policy: CachePolicy) async throws -> CacheResult<Movie> {
        guard !failingMovieIDs.contains(id), let movie = movies[id] else {
            throw InputAssemblyTestError.failed
        }
        return CacheResult(value: movie, isStale: false)
    }

    func getTopRated(page: Int, policy: CachePolicy) async throws -> CacheResult<MoviePage> {
        throw InputAssemblyTestError.failed
    }

    func getSimilarMovies(
        id: Int,
        page: Int,
        policy: CachePolicy
    ) async throws -> CacheResult<MoviePage> {
        throw InputAssemblyTestError.failed
    }

    func getCredits(id: Int, policy: CachePolicy) async throws -> CacheResult<Credits> {
        throw InputAssemblyTestError.failed
    }

    func searchMovies(query: String, page: Int) async throws -> MoviePage {
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
        region: ViewingRegion,
        policy: AvailabilityFetchPolicy
    ) async throws -> VerifiedAvailabilityEvidence? {
        requestCount += 1
        requestedMovieIDs.append(movieID)
        activeRequestCount += 1
        maximumActiveRequestCount = max(
            maximumActiveRequestCount,
            activeRequestCount
        )
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
        guard requestCount < expectedCount else {
            return
        }
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

private func makeCompletedProfileRepository() async throws -> DefaultViewerProfileRepository {
    let repository = DefaultViewerProfileRepository(store: InMemoryViewerProfileDataStore())
    _ = try await ViewerProfileTestFixtures.completedProfile(in: repository)
    return repository
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

private func watchlistItem(id: Int, isWatched: Bool) -> WatchlistItem {
    WatchlistItem(
        id: id,
        addedAt: Date(timeIntervalSince1970: TimeInterval(id)),
        isWatched: isWatched,
        movie: MovieSummary(
            id: id,
            title: "Movie \(id)",
            posterPath: nil,
            releaseYear: 2010,
            rating: 8
        )
    )
}

private func calibrationMovies(
    for reactions: [Int: CalibrationReaction]
) -> [Int: Movie] {
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
