import Foundation
@testable import PickOne
import Testing

@MainActor
@Suite("MovieDetailViewModel Tests", .serialized)
struct MovieDetailViewModelTests {
    @Test("load sets loaded state")
    func loadSetsLoadedState() async {
        let useCase = MockGetMovieDetailUseCase(results: [
            .success(CacheResult(value: TestFixtures.snapshot, isStale: false)),
        ])

        let sut = makeSUT(getMovieDetail: useCase)
        await sut.load()

        guard case let .loaded(data) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(data.title == "Movie A")
        #expect(data.similar.count == 1)
    }

    @Test("stale refresh overrides loaded state")
    func staleRefreshOverridesLoadedState() async {
        let useCase = MockGetMovieDetailUseCase(results: [
            .success(CacheResult(value: TestFixtures.snapshot, isStale: true)),
            .success(CacheResult(value: TestFixtures.refreshedSnapshot, isStale: false)),
        ])

        let sut = makeSUT(getMovieDetail: useCase)
        await sut.load()

        guard case let .loaded(data) = sut.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(data.title == "Movie B")
    }

    @Test("load error sets error state")
    func loadErrorSetsErrorState() async {
        let useCase = MockGetMovieDetailUseCase(results: [
            .failure(TestError.fetchFailed),
        ])

        let sut = makeSUT(getMovieDetail: useCase)
        await sut.load()

        guard case .error = sut.state else {
            Issue.record("Expected error state")
            return
        }
    }

    @Test("removing Watchlist intent from watched-only Detail keeps persisted and visible state")
    func removingWatchlistIntentFromWatchedOnlyDetailIsTruthfulNoOp() async throws {
        let snapshotID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let watched = try ViewerMovieState(
            movieID: 1,
            displayMetadata: LocalViewerStateTestFixtures.metadata(),
            watchState: .watched,
            preference: nil,
            watchlistIntent: nil,
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let envelope = LocalViewerStateEnvelopeMapper().replacingStates(
            in: LocalViewerStateTestFixtures.emptyEnvelope(id: snapshotID),
            snapshotID: snapshotID,
            states: [watched]
        )
        let files = try InMemoryLocalViewerStateFileStore(
            activeData: LocalViewerStateTestFixtures.encoded(envelope)
        )
        let stateRepository = LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource()
        )
        let watchlistRepository = LocalViewerStateWatchlistAdapter(
            repository: stateRepository
        )
        var changes: [DecisionEligibilityChange] = []
        let sut = MovieDetailViewModel(
            movieId: watched.movieID,
            getMovieDetail: MockGetMovieDetailUseCase(results: [
                .success(CacheResult(value: TestFixtures.watchedSnapshot, isStale: false)),
            ]),
            setMembership: SetWatchlistMembership(repository: watchlistRepository),
            setWatched: SetWatched(repository: watchlistRepository),
            checkAvailability: UnknownMovieAvailability(),
            preparePlaybackOptions: UnavailablePlaybackOptions(),
            eligibilityDidChange: { changes.append($0) }
        )

        await sut.load()
        await sut.toggleWatchlist()

        guard case let .loaded(model) = sut.state else {
            Issue.record("Expected Detail to remain loaded")
            return
        }
        #expect(model.isInWatchlist)
        #expect(model.isWatched)
        #expect(try await stateRepository.state(movieID: watched.movieID) == watched)
        #expect(changes.isEmpty)
        #expect(files.activeReplacementCount == 0)
    }

    private func makeSUT(
        getMovieDetail: GetMovieDetailUseCase
    ) -> MovieDetailViewModel {
        MovieDetailViewModel(
            movieId: 1,
            getMovieDetail: getMovieDetail,
            setMembership: NoOpSetWatchlistMembership(),
            setWatched: NoOpSetWatched(),
            checkAvailability: UnknownMovieAvailability(),
            preparePlaybackOptions: UnavailablePlaybackOptions()
        )
    }
}

private struct NoOpSetWatchlistMembership: SetWatchlistMembershipUseCase {
    func execute(movie: MovieSummary, isInWatchlist: Bool) throws -> Bool {
        true
    }
}

private struct NoOpSetWatched: SetWatchedUseCase {
    func execute(movieId: Int, isWatched: Bool) throws -> Bool {
        true
    }
}

private struct UnknownMovieAvailability: CheckMovieAvailabilityUseCase {
    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) async throws -> AvailabilityOutcome {
        .unknown(reason: .regionalEvidenceMissing)
    }
}

private struct UnavailablePlaybackOptions: PreparePlaybackOptionsUseCase {
    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) async throws -> PlaybackOptionsPreparation {
        .unavailable
    }
}

private actor MockGetMovieDetailUseCase: GetMovieDetailUseCase {
    private let results: [Result<CacheResult<MovieDetailSnapshot>, Error>]
    private var callIndex = 0

    init(results: [Result<CacheResult<MovieDetailSnapshot>, Error>]) {
        self.results = results
    }

    func execute(id: Int, policy: CachePolicy) async throws -> CacheResult<MovieDetailSnapshot> {
        defer { callIndex += 1 }
        return try results[callIndex].get()
    }
}

private enum TestError: Error {
    case fetchFailed
}

private enum TestFixtures {
    static let snapshot = MovieDetailSnapshot(
        movie: Movie(
            id: 1,
            title: "Movie A",
            originalTitle: "Movie A",
            overview: "Overview",
            releaseDate: nil,
            runtime: 120,
            rating: 8.0,
            voteCount: 100,
            posterPath: "/posterA.jpg",
            backdropPath: "/backdropA.jpg",
            genres: [],
            tagline: nil
        ),
        similar: [
            MovieSummary(id: 2, title: "Movie B", posterPath: "/posterB.jpg", releaseYear: 2022, rating: 7.4),
        ],
        isInWatchlist: false,
        isWatched: false,
        director: Person(id: 10, name: "Director", profilePath: nil, role: .director),
        topCast: [Person(id: 11, name: "Actor", profilePath: nil, role: .cast(character: "Hero"))],
        isSimilarUnavailable: false,
        isCreditsUnavailable: false,
        asOf: Date()
    )

    static let refreshedSnapshot = MovieDetailSnapshot(
        movie: Movie(
            id: 1,
            title: "Movie B",
            originalTitle: "Movie B",
            overview: "Overview",
            releaseDate: nil,
            runtime: 121,
            rating: 8.2,
            voteCount: 110,
            posterPath: "/posterB.jpg",
            backdropPath: "/backdropB.jpg",
            genres: [],
            tagline: nil
        ),
        similar: [],
        isInWatchlist: false,
        isWatched: false,
        director: nil,
        topCast: [],
        isSimilarUnavailable: true,
        isCreditsUnavailable: true,
        asOf: Date()
    )

    static let watchedSnapshot = MovieDetailSnapshot(
        movie: snapshot.movie,
        similar: snapshot.similar,
        isInWatchlist: true,
        isWatched: true,
        director: snapshot.director,
        topCast: snapshot.topCast,
        isSimilarUnavailable: snapshot.isSimilarUnavailable,
        isCreditsUnavailable: snapshot.isCreditsUnavailable,
        asOf: snapshot.asOf
    )
}
