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

        let outcome = try await sut.execute(movie: movie, isInWatchlist: true)

        #expect(outcome == WatchlistMutationOutcome(status: .toWatch, didChange: true))
        #expect(repository.membershipCallCount == 1)
        #expect(repository.lastMembershipMovie?.id == movie.id)
        #expect(repository.lastMembershipValue == true)
        #expect(repository.getStatusCallCount == 0)
    }

    @Test("execute removes movie when isInWatchlist is false and in watchlist")
    func executeRemovesMovieWhenFalse() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // Already in watchlist
        let sut = SetWatchlistMembership(repository: repository)
        let movie = WatchlistTestFixtures.movieSummary

        let outcome = try await sut.execute(movie: movie, isInWatchlist: false)

        #expect(outcome == WatchlistMutationOutcome(status: .notInWatchlist, didChange: true))
        #expect(repository.membershipCallCount == 1)
        #expect(repository.lastMembershipMovie?.id == movie.id)
        #expect(repository.lastMembershipValue == false)
        #expect(repository.getStatusCallCount == 0)
    }

    @Test("execute is idempotent - no-op when already in watchlist and adding")
    func executeIsIdempotentWhenAddingExisting() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // Already in watchlist
        let sut = SetWatchlistMembership(repository: repository)

        let outcome = try await sut.execute(
            movie: WatchlistTestFixtures.movieSummary,
            isInWatchlist: true
        )

        #expect(outcome == WatchlistMutationOutcome(status: .toWatch, didChange: false))
        #expect(repository.membershipCallCount == 1)
        #expect(repository.getStatusCallCount == 0)
    }

    @Test("execute is idempotent - no-op when not in watchlist and removing")
    func executeIsIdempotentWhenRemovingNonExisting() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist // Not in watchlist
        let sut = SetWatchlistMembership(repository: repository)

        let outcome = try await sut.execute(
            movie: WatchlistTestFixtures.movieSummary,
            isInWatchlist: false
        )

        #expect(outcome == WatchlistMutationOutcome(status: .notInWatchlist, didChange: false))
        #expect(repository.membershipCallCount == 1)
        #expect(repository.getStatusCallCount == 0)
    }

    @Test("removing membership from watched-only compatibility state is a semantic no-op")
    func removingMembershipFromWatchedOnlyStateIsNoOp() async throws {
        let repository = MockWatchlistRepository()
        repository.statusResult = .watched
        let sut = SetWatchlistMembership(repository: repository)

        let outcome = try await sut.execute(
            movie: WatchlistTestFixtures.movieSummary,
            isInWatchlist: false
        )

        #expect(outcome == WatchlistMutationOutcome(status: .watched, didChange: false))
        #expect(repository.membershipCallCount == 1)
        #expect(repository.getStatusCallCount == 0)
    }

    @Test("execute propagates add error")
    func executePropagatesAddError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist
        repository.membershipError = WatchlistError.movieAlreadyInWatchlist
        let sut = SetWatchlistMembership(repository: repository)

        await #expect(throws: WatchlistError.movieAlreadyInWatchlist) {
            try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: true)
        }
    }

    @Test("execute propagates remove error")
    func executePropagatesRemoveError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .toWatch // In watchlist so remove will be called
        repository.membershipError = WatchlistError.movieNotInWatchlist
        let sut = SetWatchlistMembership(repository: repository)

        await #expect(throws: WatchlistError.movieNotInWatchlist) {
            try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: false)
        }
    }
}
