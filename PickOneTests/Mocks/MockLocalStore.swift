//
//  MockLocalStore.swift
//  PickOneTests
//
//  Mock implementation of LocalStore for testing
//

import Foundation
@testable import PickOne
import Synchronization

final class MockLocalStore: LocalStore {
    private struct State: Sendable {
        var watchlistItems: [PersistedWatchlistItem] = []
        var loadWatchlistItemsError: LocalStoreError?
        var searchHistory: [String] = []
        var saveWatchlistItemCallCount = 0
        var removeWatchlistItemCallCount = 0
        var updateWatchedStatusCallCount = 0
        var lastSavedItem: PersistedWatchlistItem?
        var lastRemovedMovieId: Int?
        var lastUpdatedMovieId: Int?
        var lastUpdatedWatchedStatus: Bool?
    }

    private let state = Mutex(State())

    private(set) var saveWatchlistItemCallCount: Int {
        get { state.withLock { $0.saveWatchlistItemCallCount } }
        set { state.withLock { $0.saveWatchlistItemCallCount = newValue } }
    }

    private(set) var removeWatchlistItemCallCount: Int {
        get { state.withLock { $0.removeWatchlistItemCallCount } }
        set { state.withLock { $0.removeWatchlistItemCallCount = newValue } }
    }

    private(set) var updateWatchedStatusCallCount: Int {
        get { state.withLock { $0.updateWatchedStatusCallCount } }
        set { state.withLock { $0.updateWatchedStatusCallCount = newValue } }
    }

    private(set) var lastSavedItem: PersistedWatchlistItem? {
        get { state.withLock { $0.lastSavedItem } }
        set { state.withLock { $0.lastSavedItem = newValue } }
    }

    private(set) var lastRemovedMovieId: Int? {
        get { state.withLock { $0.lastRemovedMovieId } }
        set { state.withLock { $0.lastRemovedMovieId = newValue } }
    }

    private(set) var lastUpdatedMovieId: Int? {
        get { state.withLock { $0.lastUpdatedMovieId } }
        set { state.withLock { $0.lastUpdatedMovieId = newValue } }
    }

    private(set) var lastUpdatedWatchedStatus: Bool? {
        get { state.withLock { $0.lastUpdatedWatchedStatus } }
        set { state.withLock { $0.lastUpdatedWatchedStatus = newValue } }
    }

    // MARK: - Watchlist Items

    var loadWatchlistItemsError: LocalStoreError? {
        get { state.withLock { $0.loadWatchlistItemsError } }
        set { state.withLock { $0.loadWatchlistItemsError = newValue } }
    }

    func loadWatchlistItems() throws -> [PersistedWatchlistItem] {
        try state.withLock {
            if let error = $0.loadWatchlistItemsError {
                throw error
            }
            return $0.watchlistItems.sorted { $0.addedAt > $1.addedAt }
        }
    }

    func getWatchlistItems() -> [PersistedWatchlistItem] {
        state.withLock {
            $0.watchlistItems.sorted { $0.addedAt > $1.addedAt }
        }
    }

    func saveWatchlistItem(_ item: PersistedWatchlistItem) throws {
        state.withLock { state in
            state.saveWatchlistItemCallCount += 1
            state.lastSavedItem = item
            state.watchlistItems.removeAll { $0.movieId == item.movieId }
            state.watchlistItems.append(item)
        }
    }

    func removeWatchlistItem(movieId: Int) throws {
        state.withLock { state in
            state.removeWatchlistItemCallCount += 1
            state.lastRemovedMovieId = movieId
            state.watchlistItems.removeAll { $0.movieId == movieId }
        }
    }

    func updateWatchedStatus(movieId: Int, isWatched: Bool) throws {
        state.withLock { state in
            state.updateWatchedStatusCallCount += 1
            state.lastUpdatedMovieId = movieId
            state.lastUpdatedWatchedStatus = isWatched

            guard let index = state.watchlistItems.firstIndex(
                where: { $0.movieId == movieId }
            ) else {
                return
            }
            state.watchlistItems[index].isWatched = isWatched
        }
    }

    func getWatchlistStatus(movieId: Int) -> (isInWatchlist: Bool, isWatched: Bool) {
        state.withLock { state in
            guard let item = state.watchlistItems.first(
                where: { $0.movieId == movieId }
            ) else {
                return (false, false)
            }
            return (true, item.isWatched)
        }
    }

    // MARK: - Search History

    func getSearchHistory() -> [String] {
        state.withLock { $0.searchHistory }
    }

    func addSearchQuery(_ query: String) {
        state.withLock { state in
            state.searchHistory.removeAll { $0 == query }
            state.searchHistory.insert(query, at: 0)
            if state.searchHistory.count > 10 {
                state.searchHistory = Array(state.searchHistory.prefix(10))
            }
        }
    }

    func clearSearchHistory() {
        state.withLock { $0.searchHistory.removeAll() }
    }

    // MARK: - Test Helpers

    func seedWatchlistItems(_ items: [PersistedWatchlistItem]) {
        state.withLock { $0.watchlistItems = items }
    }

    func reset() {
        state.withLock { $0 = State() }
    }
}
