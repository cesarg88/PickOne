//
//  SetWatchlistMembershipTests.swift
//  PickOneTests
//
//  Tests for SetWatchlistMembership use case
//

import Foundation
@testable import PickOne
import Testing

@Suite("SetWatchlistMembership Tests", .serialized)
struct SetWatchlistMembershipTests {
    @Test("execute adds movie when isInWatchlist is true and not in watchlist")
    func executeAddsMovieWhenTrue() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist // Not yet in watchlist
        let sut = SetWatchlistMembership(repository: repository)
        let movie = WatchlistTestFixtures.movieSummary

        try await sut.execute(movie: movie, isInWatchlist: true)

        #expect(repository.addCallCount == 1)
        #expect(repository.lastAddedMovie?.id == movie.id)
        #expect(repository.removeCallCount == 0)
    }

    @Test("execute removes movie when isInWatchlist is false and in watchlist")
    func executeRemovesMovieWhenFalse() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // Already in watchlist
        let sut = SetWatchlistMembership(repository: repository)
        let movie = WatchlistTestFixtures.movieSummary

        try await sut.execute(movie: movie, isInWatchlist: false)

        #expect(repository.removeCallCount == 1)
        #expect(repository.lastRemovedMovieId == movie.id)
        #expect(repository.addCallCount == 0)
    }

    @Test("execute is idempotent - no-op when already in watchlist and adding")
    func executeIsIdempotentWhenAddingExisting() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // Already in watchlist
        let sut = SetWatchlistMembership(repository: repository)

        try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: true)

        #expect(repository.addCallCount == 0) // No call, already in watchlist
    }

    @Test("execute is idempotent - no-op when not in watchlist and removing")
    func executeIsIdempotentWhenRemovingNonExisting() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist // Not in watchlist
        let sut = SetWatchlistMembership(repository: repository)

        try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: false)

        #expect(repository.removeCallCount == 0) // No call, not in watchlist anyway
    }

    @Test("execute propagates add error")
    func executePropagatesAddError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist
        repository.addError = WatchlistError.movieAlreadyInWatchlist
        let sut = SetWatchlistMembership(repository: repository)

        await #expect(throws: WatchlistError.movieAlreadyInWatchlist) {
            try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: true)
        }
    }

    @Test("execute propagates remove error")
    func executePropagatesRemoveError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // In watchlist so remove will be called
        repository.removeError = WatchlistError.movieNotInWatchlist
        let sut = SetWatchlistMembership(repository: repository)

        await #expect(throws: WatchlistError.movieNotInWatchlist) {
            try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: false)
        }
    }
}
