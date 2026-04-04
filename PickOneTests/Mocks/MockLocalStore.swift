//
//  MockLocalStore.swift
//  PickOneTests
//
//  Mock implementation of LocalStoreProtocol for testing
//

import Foundation
@testable import PickOne

final class MockLocalStore: LocalStoreProtocol, @unchecked Sendable {
    
    // MARK: - Storage
    
    private var watchlistItems: [PersistedWatchlistItem] = []
    private var searchHistory: [String] = []
    
    // MARK: - Call Tracking
    
    private(set) var saveWatchlistItemCallCount = 0
    private(set) var removeWatchlistItemCallCount = 0
    private(set) var updateWatchedStatusCallCount = 0
    private(set) var lastSavedItem: PersistedWatchlistItem?
    private(set) var lastRemovedMovieId: Int?
    private(set) var lastUpdatedMovieId: Int?
    private(set) var lastUpdatedWatchedStatus: Bool?
    
    // MARK: - Watchlist Items
    
    func getWatchlistItems() -> [PersistedWatchlistItem] {
        watchlistItems.sorted { $0.addedAt > $1.addedAt }
    }
    
    func saveWatchlistItem(_ item: PersistedWatchlistItem) {
        saveWatchlistItemCallCount += 1
        lastSavedItem = item
        
        // Remove existing if present
        watchlistItems.removeAll { $0.movieId == item.movieId }
        watchlistItems.append(item)
    }
    
    func removeWatchlistItem(movieId: Int) {
        removeWatchlistItemCallCount += 1
        lastRemovedMovieId = movieId
        watchlistItems.removeAll { $0.movieId == movieId }
    }
    
    func updateWatchedStatus(movieId: Int, isWatched: Bool) {
        updateWatchedStatusCallCount += 1
        lastUpdatedMovieId = movieId
        lastUpdatedWatchedStatus = isWatched
        
        guard let index = watchlistItems.firstIndex(where: { $0.movieId == movieId }) else {
            return
        }
        
        let item = watchlistItems[index]
        watchlistItems[index] = PersistedWatchlistItem(
            movieId: item.movieId,
            title: item.title,
            posterPath: item.posterPath,
            releaseYear: item.releaseYear,
            rating: item.rating,
            addedAt: item.addedAt,
            isWatched: isWatched
        )
    }
    
    func getWatchlistStatus(movieId: Int) -> (isInWatchlist: Bool, isWatched: Bool) {
        guard let item = watchlistItems.first(where: { $0.movieId == movieId }) else {
            return (false, false)
        }
        return (true, item.isWatched)
    }
    
    // MARK: - Search History
    
    func getSearchHistory() -> [String] {
        searchHistory
    }
    
    func addSearchQuery(_ query: String) {
        searchHistory.removeAll { $0 == query }
        searchHistory.insert(query, at: 0)
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
    }
    
    // MARK: - Test Helpers
    
    func seedWatchlistItems(_ items: [PersistedWatchlistItem]) {
        watchlistItems = items
    }
    
    func reset() {
        watchlistItems.removeAll()
        searchHistory.removeAll()
        saveWatchlistItemCallCount = 0
        removeWatchlistItemCallCount = 0
        updateWatchedStatusCallCount = 0
        lastSavedItem = nil
        lastRemovedMovieId = nil
        lastUpdatedMovieId = nil
        lastUpdatedWatchedStatus = nil
    }
}
