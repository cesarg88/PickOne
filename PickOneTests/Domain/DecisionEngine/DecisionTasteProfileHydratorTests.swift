import Foundation
@testable import PickOne
import Testing

@Suite("Decision Taste Profile hydration")
struct DecisionTasteProfileHydratorTests {
    @Test("hydrates every reaction four-wide and assembles ascending movie-ID evidence")
    func hydratesDeterministicallyWithBoundedConcurrency() async throws {
        let reactions: [Int: MovieReaction] = [
            40: .didNotLikeIt,
            10: .loveIt,
            30: .itWasOkay,
            20: .likeIt,
            60: .loveIt,
            50: .likeIt,
        ]
        let repository = HydrationMovieRepository(
            movies: Dictionary(uniqueKeysWithValues: reactions.keys.map {
                ($0, hydrationMovie(id: $0))
            }),
            delays: [
                10: .milliseconds(40),
                20: .milliseconds(30),
                30: .milliseconds(20),
                40: .milliseconds(10),
            ]
        )
        let sut = HydrateDecisionTasteProfile(movieRepository: repository)

        let profile = try await sut.execute(reactions: reactions)

        #expect(profile.evidence.map(\.movieID) == [10, 20, 30, 40, 50, 60])
        #expect(profile.evidence.map(\.reaction) == [
            .loveIt,
            .likeIt,
            .itWasOkay,
            .didNotLikeIt,
            .likeIt,
            .loveIt,
        ])
        #expect(await repository.maximumActiveRequestCount == 4)
        #expect(await repository.requestedMovieIDs.count == reactions.count)
    }

    @Test("reports the lowest failed movie ID only after all bounded work completes")
    func reportsDeterministicLowestFailure() async throws {
        let reactions = Dictionary(
            uniqueKeysWithValues: (1 ... 7).map { ($0, MovieReaction.likeIt) }
        )
        let repository = HydrationMovieRepository(
            movies: Dictionary(uniqueKeysWithValues: reactions.keys.map {
                ($0, hydrationMovie(id: $0))
            }),
            failingMovieIDs: [1, 4]
        )
        let sut = HydrateDecisionTasteProfile(movieRepository: repository)

        await #expect(
            throws: DecisionTasteProfileHydrationError.movieUnavailable(movieID: 1)
        ) {
            _ = try await sut.execute(reactions: reactions)
        }
        #expect(await repository.requestedMovieIDs.count == reactions.count)
        #expect(await repository.maximumActiveRequestCount <= 4)
    }

    @Test("caller cancellation stops every structured hydration child")
    func cancellationStopsStructuredChildren() async throws {
        let reactions = Dictionary(
            uniqueKeysWithValues: (1 ... 8).map { ($0, MovieReaction.likeIt) }
        )
        let repository = HydrationMovieRepository(
            movies: [:],
            suspendsUntilCancelled: true
        )
        let sut = HydrateDecisionTasteProfile(movieRepository: repository)
        let hydration = Task {
            try await sut.execute(reactions: reactions)
        }

        await repository.waitUntilRequestCount(4)
        hydration.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await hydration.value
        }
        #expect(await repository.requestedMovieIDs.count == 4)
        #expect(await repository.cancellationCount == 4)
    }
}

private enum HydrationTestError: Error {
    case failed
}

private actor HydrationMovieRepository: MovieRepository {
    private let movies: [Int: Movie]
    private let delays: [Int: Duration]
    private let failingMovieIDs: Set<Int>
    private let suspendsUntilCancelled: Bool
    private var activeRequestCount = 0
    private var requestCountWaiters: [HydrationRequestCountWaiter] = []
    private(set) var requestedMovieIDs: [Int] = []
    private(set) var maximumActiveRequestCount = 0
    private(set) var cancellationCount = 0

    init(
        movies: [Int: Movie],
        delays: [Int: Duration] = [:],
        failingMovieIDs: Set<Int> = [],
        suspendsUntilCancelled: Bool = false
    ) {
        self.movies = movies
        self.delays = delays
        self.failingMovieIDs = failingMovieIDs
        self.suspendsUntilCancelled = suspendsUntilCancelled
    }

    func getMovieDetail(id: Int, policy _: CachePolicy) async throws -> CacheResult<Movie> {
        requestedMovieIDs.append(id)
        activeRequestCount += 1
        maximumActiveRequestCount = max(maximumActiveRequestCount, activeRequestCount)
        resumeSatisfiedWaiters()
        defer { activeRequestCount -= 1 }

        do {
            if suspendsUntilCancelled {
                try await Task.sleep(for: .seconds(60))
            }
            if let delay = delays[id] {
                try await Task.sleep(for: delay)
            }
        } catch is CancellationError {
            cancellationCount += 1
            throw CancellationError()
        }

        guard !failingMovieIDs.contains(id), let movie = movies[id] else {
            throw HydrationTestError.failed
        }
        return CacheResult(value: movie, isStale: false)
    }

    func waitUntilRequestCount(_ count: Int) async {
        guard requestedMovieIDs.count < count else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters.append(HydrationRequestCountWaiter(
                count: count,
                continuation: continuation
            ))
        }
    }

    func getTopRated(page _: Int, policy _: CachePolicy) async throws -> CacheResult<MoviePage> {
        throw HydrationTestError.failed
    }

    func getSimilarMovies(
        id _: Int,
        page _: Int,
        policy _: CachePolicy
    ) async throws -> CacheResult<MoviePage> {
        throw HydrationTestError.failed
    }

    func getCredits(id _: Int, policy _: CachePolicy) async throws -> CacheResult<Credits> {
        throw HydrationTestError.failed
    }

    func searchMovies(query _: String, page _: Int) async throws -> MoviePage {
        throw HydrationTestError.failed
    }

    private func resumeSatisfiedWaiters() {
        var pending: [HydrationRequestCountWaiter] = []
        for waiter in requestCountWaiters {
            if requestedMovieIDs.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        requestCountWaiters = pending
    }
}

private struct HydrationRequestCountWaiter {
    let count: Int
    let continuation: CheckedContinuation<Void, Never>
}

private func hydrationMovie(id: Int) -> Movie {
    Movie(
        id: id,
        title: "Movie \(id)",
        originalTitle: "Movie \(id)",
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
}
