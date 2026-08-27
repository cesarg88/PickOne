//
//  MockWatchlistRepository.swift
//  PickOneTests
//
//  Mock implementation of WatchlistRepository for testing
//

import Foundation
@testable import PickOne
import Synchronization

final class MockWatchlistRepository: WatchlistRepository {
    private struct State: Sendable {
        var getAllItemsResult: [WatchlistItem] = []
        var membershipError: WatchlistError?
        var setWatchedError: WatchlistError?
        var statusResult: WatchlistStatus = .notInWatchlist
        var getAllItemsCallCount = 0
        var membershipCallCount = 0
        var setWatchedCallCount = 0
        var getStatusCallCount = 0
        var lastMembershipMovie: MovieSummary?
        var lastMembershipValue: Bool?
        var lastSetWatchedMovieId: Int?
        var lastSetWatchedValue: Bool?
        var lastGetStatusMovieId: Int?
    }

    private let state = Mutex(State())

    var getAllItemsResult: [WatchlistItem] {
        get { state.withLock { $0.getAllItemsResult } }
        set { state.withLock { $0.getAllItemsResult = newValue } }
    }

    var membershipError: WatchlistError? {
        get { state.withLock { $0.membershipError } }
        set { state.withLock { $0.membershipError = newValue } }
    }

    var setWatchedError: WatchlistError? {
        get { state.withLock { $0.setWatchedError } }
        set { state.withLock { $0.setWatchedError = newValue } }
    }

    var statusResult: WatchlistStatus {
        get { state.withLock { $0.statusResult } }
        set { state.withLock { $0.statusResult = newValue } }
    }

    private(set) var getAllItemsCallCount: Int {
        get { state.withLock { $0.getAllItemsCallCount } }
        set { state.withLock { $0.getAllItemsCallCount = newValue } }
    }

    var loadAllItemsCallCount: Int {
        getAllItemsCallCount
    }

    private(set) var membershipCallCount: Int {
        get { state.withLock { $0.membershipCallCount } }
        set { state.withLock { $0.membershipCallCount = newValue } }
    }

    private(set) var setWatchedCallCount: Int {
        get { state.withLock { $0.setWatchedCallCount } }
        set { state.withLock { $0.setWatchedCallCount = newValue } }
    }

    private(set) var getStatusCallCount: Int {
        get { state.withLock { $0.getStatusCallCount } }
        set { state.withLock { $0.getStatusCallCount = newValue } }
    }

    private(set) var lastMembershipMovie: MovieSummary? {
        get { state.withLock { $0.lastMembershipMovie } }
        set { state.withLock { $0.lastMembershipMovie = newValue } }
    }

    private(set) var lastMembershipValue: Bool? {
        get { state.withLock { $0.lastMembershipValue } }
        set { state.withLock { $0.lastMembershipValue = newValue } }
    }

    private(set) var lastSetWatchedMovieId: Int? {
        get { state.withLock { $0.lastSetWatchedMovieId } }
        set { state.withLock { $0.lastSetWatchedMovieId = newValue } }
    }

    private(set) var lastSetWatchedValue: Bool? {
        get { state.withLock { $0.lastSetWatchedValue } }
        set { state.withLock { $0.lastSetWatchedValue = newValue } }
    }

    private(set) var lastGetStatusMovieId: Int? {
        get { state.withLock { $0.lastGetStatusMovieId } }
        set { state.withLock { $0.lastGetStatusMovieId = newValue } }
    }

    // MARK: - WatchlistRepository

    func loadAllItems() async throws -> [WatchlistItem] {
        state.withLock {
            $0.getAllItemsCallCount += 1
            return $0.getAllItemsResult
        }
    }

    func setMembership(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) async throws -> WatchlistMutationOutcome {
        try state.withLock {
            $0.membershipCallCount += 1
            $0.lastMembershipMovie = movie
            $0.lastMembershipValue = isInWatchlist
            if let error = $0.membershipError {
                throw error
            }
            let outcome = membershipOutcome(
                status: $0.statusResult,
                isInWatchlist: isInWatchlist
            )
            $0.statusResult = outcome.status
            return outcome
        }
    }

    func setWatched(
        movieId: Int,
        isWatched: Bool
    ) async throws -> WatchlistMutationOutcome {
        try state.withLock {
            $0.setWatchedCallCount += 1
            $0.lastSetWatchedMovieId = movieId
            $0.lastSetWatchedValue = isWatched
            if let error = $0.setWatchedError {
                throw error
            }
            guard $0.statusResult != .notInWatchlist else {
                throw WatchlistError.movieNotInWatchlist
            }
            let requestedStatus: WatchlistStatus = isWatched ? .watched : .toWatch
            let outcome = WatchlistMutationOutcome(
                status: requestedStatus,
                didChange: $0.statusResult != requestedStatus
            )
            $0.statusResult = requestedStatus
            return outcome
        }
    }

    func getStatus(movieId: Int) async throws -> WatchlistStatus {
        state.withLock {
            $0.getStatusCallCount += 1
            $0.lastGetStatusMovieId = movieId
            return $0.statusResult
        }
    }

    // MARK: - Test Helpers

    func reset() {
        state.withLock { $0 = State() }
    }

    private func membershipOutcome(
        status: WatchlistStatus,
        isInWatchlist: Bool
    ) -> WatchlistMutationOutcome {
        if isInWatchlist {
            return WatchlistMutationOutcome(
                status: status == .notInWatchlist ? .toWatch : status,
                didChange: status == .notInWatchlist
            )
        }
        return WatchlistMutationOutcome(
            status: status == .toWatch ? .notInWatchlist : status,
            didChange: status == .toWatch
        )
    }
}
