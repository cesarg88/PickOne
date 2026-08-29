//
//  MockWatchlistRepository.swift
//  PickOneTests
//
//  Mock implementation of WatchlistRepository for testing
//

import Foundation
@testable import PickOne
import Synchronization

enum MockWatchlistRepositoryError: Error, Equatable {
    case failed
}

final class MockWatchlistRepository: WatchlistRepository {
    private struct State: Sendable {
        var getAllItemsResult: [WatchlistItem] = []
        var membershipError: MockWatchlistRepositoryError?
        var statusResult: WatchlistStatus = .notInWatchlist
        var getAllItemsCallCount = 0
        var membershipCallCount = 0
        var lastMembershipMovie: MovieSummary?
        var lastMembershipValue: Bool?
    }

    private let state = Mutex(State())

    var getAllItemsResult: [WatchlistItem] {
        get { state.withLock { $0.getAllItemsResult } }
        set { state.withLock { $0.getAllItemsResult = newValue } }
    }

    var membershipError: MockWatchlistRepositoryError? {
        get { state.withLock { $0.membershipError } }
        set { state.withLock { $0.membershipError = newValue } }
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

    private(set) var lastMembershipMovie: MovieSummary? {
        get { state.withLock { $0.lastMembershipMovie } }
        set { state.withLock { $0.lastMembershipMovie = newValue } }
    }

    private(set) var lastMembershipValue: Bool? {
        get { state.withLock { $0.lastMembershipValue } }
        set { state.withLock { $0.lastMembershipValue = newValue } }
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
