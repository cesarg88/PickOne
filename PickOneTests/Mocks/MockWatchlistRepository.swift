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
        var addError: WatchlistError?
        var removeError: WatchlistError?
        var setWatchedError: WatchlistError?
        var statusResult: WatchlistStatus = .notInWatchlist
        var getAllItemsCallCount = 0
        var addCallCount = 0
        var removeCallCount = 0
        var setWatchedCallCount = 0
        var getStatusCallCount = 0
        var lastAddedMovie: MovieSummary?
        var lastRemovedMovieId: Int?
        var lastSetWatchedMovieId: Int?
        var lastSetWatchedValue: Bool?
        var lastGetStatusMovieId: Int?
    }

    private let state = Mutex(State())

    var getAllItemsResult: [WatchlistItem] {
        get { state.withLock { $0.getAllItemsResult } }
        set { state.withLock { $0.getAllItemsResult = newValue } }
    }

    var addError: WatchlistError? {
        get { state.withLock { $0.addError } }
        set { state.withLock { $0.addError = newValue } }
    }

    var removeError: WatchlistError? {
        get { state.withLock { $0.removeError } }
        set { state.withLock { $0.removeError = newValue } }
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

    private(set) var addCallCount: Int {
        get { state.withLock { $0.addCallCount } }
        set { state.withLock { $0.addCallCount = newValue } }
    }

    private(set) var removeCallCount: Int {
        get { state.withLock { $0.removeCallCount } }
        set { state.withLock { $0.removeCallCount = newValue } }
    }

    private(set) var setWatchedCallCount: Int {
        get { state.withLock { $0.setWatchedCallCount } }
        set { state.withLock { $0.setWatchedCallCount = newValue } }
    }

    private(set) var getStatusCallCount: Int {
        get { state.withLock { $0.getStatusCallCount } }
        set { state.withLock { $0.getStatusCallCount = newValue } }
    }

    private(set) var lastAddedMovie: MovieSummary? {
        get { state.withLock { $0.lastAddedMovie } }
        set { state.withLock { $0.lastAddedMovie = newValue } }
    }

    private(set) var lastRemovedMovieId: Int? {
        get { state.withLock { $0.lastRemovedMovieId } }
        set { state.withLock { $0.lastRemovedMovieId = newValue } }
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

    func getAllItems() -> [WatchlistItem] {
        state.withLock {
            $0.getAllItemsCallCount += 1
            return $0.getAllItemsResult
        }
    }

    func add(movie: MovieSummary) throws {
        try state.withLock {
            $0.addCallCount += 1
            $0.lastAddedMovie = movie
            if let error = $0.addError {
                throw error
            }
        }
    }

    func remove(movieId: Int) throws {
        try state.withLock {
            $0.removeCallCount += 1
            $0.lastRemovedMovieId = movieId
            if let error = $0.removeError {
                throw error
            }
        }
    }

    func setWatched(movieId: Int, isWatched: Bool) throws {
        try state.withLock {
            $0.setWatchedCallCount += 1
            $0.lastSetWatchedMovieId = movieId
            $0.lastSetWatchedValue = isWatched
            if let error = $0.setWatchedError {
                throw error
            }
        }
    }

    func getStatus(movieId: Int) -> WatchlistStatus {
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
}
