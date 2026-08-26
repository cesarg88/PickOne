//
//  SetWatchedTests.swift
//  PickOneTests
//
//  Tests for SetWatched use case
//

import Foundation
@testable import PickOne
import Testing

@Suite("SetWatched Tests", .serialized)
struct SetWatchedTests {
    @Test("execute sets watched to true when in watchlist as toWatch")
    func executeSetsWatchedTrue() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // Movie is in watchlist, not watched
        let sut = SetWatched(repository: repository)

        try await sut.execute(movieId: 1, isWatched: true)

        #expect(repository.setWatchedCallCount == 1)
        #expect(repository.lastSetWatchedMovieId == 1)
        #expect(repository.lastSetWatchedValue == true)
    }

    @Test("execute sets watched to false when in watchlist as watched")
    func executeSetsWatchedFalse() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .watched // Movie is in watchlist, already watched
        let sut = SetWatched(repository: repository)

        try await sut.execute(movieId: 1, isWatched: false)

        #expect(repository.setWatchedCallCount == 1)
        #expect(repository.lastSetWatchedValue == false)
    }

    @Test("execute throws when movie not in watchlist")
    func executePropagatesError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist
        let sut = SetWatched(repository: repository)

        await #expect(throws: WatchlistError.movieNotInWatchlist) {
            try await sut.execute(movieId: 999, isWatched: true)
        }
    }

    @Test("execute is idempotent - no-op when already in desired state")
    func executeIsIdempotentWhenAlreadyInState() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .watched // Already watched
        let sut = SetWatched(repository: repository)

        // Calling with isWatched: true when already watched should be a no-op
        try await sut.execute(movieId: 1, isWatched: true)

        #expect(repository.setWatchedCallCount == 0) // No call needed, already in state
    }

    @Test("execute propagates repository error on actual update")
    func executePropagatesRepositoryError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // In watchlist
        repository.setWatchedError = WatchlistError.movieNotInWatchlist
        let sut = SetWatched(repository: repository)

        await #expect(throws: WatchlistError.movieNotInWatchlist) {
            try await sut.execute(movieId: 1, isWatched: true)
        }
    }
}
