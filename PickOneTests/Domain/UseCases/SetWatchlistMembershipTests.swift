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
    }

    @Test("execute propagates repository error")
    func executePropagatesRepositoryError() async {
        let repository = MockWatchlistRepository()
        repository.statusResult = .notInWatchlist
        repository.membershipError = .failed
        let sut = SetWatchlistMembership(repository: repository)

        await #expect(throws: MockWatchlistRepositoryError.failed) {
            try await sut.execute(movie: WatchlistTestFixtures.movieSummary, isInWatchlist: true)
        }
    }
}
