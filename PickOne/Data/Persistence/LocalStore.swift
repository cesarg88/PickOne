//
//  LocalStore.swift
//  PickOne
//
//  Local persistence for user state (watchlist, watched status, ordering)
//

import Foundation

// MARK: - Persisted Models

/// Persisted watchlist item with embedded movie summary for offline access
struct PersistedWatchlistItem: Codable, Equatable {
    let movieId: Int
    let title: String
    let posterPath: String?
    let releaseYear: Int?
    let rating: Double
    let addedAt: Date
    var isWatched: Bool
}

// MARK: - Protocol

protocol LocalStoreProtocol: Sendable {
    // Watchlist with persisted summaries
    func getWatchlistItems() -> [PersistedWatchlistItem]
    func saveWatchlistItem(_ item: PersistedWatchlistItem)
    func removeWatchlistItem(movieId: Int)
    func updateWatchedStatus(movieId: Int, isWatched: Bool)
    func getWatchlistStatus(movieId: Int) -> (isInWatchlist: Bool, isWatched: Bool)
    
    // Search history
    func getSearchHistory() -> [String]
    func addSearchQuery(_ query: String)
    func clearSearchHistory()
}

final class UserDefaultsLocalStore: LocalStoreProtocol, @unchecked Sendable {
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private enum Keys {
        static let watchlistItems = "watchlist_items_v2"
        static let searchHistory = "search_history"
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Watchlist Items
    
    func getWatchlistItems() -> [PersistedWatchlistItem] {
        guard let data = userDefaults.data(forKey: Keys.watchlistItems) else {
            return []
        }
        do {
            let items = try decoder.decode([PersistedWatchlistItem].self, from: data)
            // Return sorted by addedAt descending (most recent first)
            return items.sorted { $0.addedAt > $1.addedAt }
        } catch {
            return []
        }
    }
    
    func saveWatchlistItem(_ item: PersistedWatchlistItem) {
        var items = getWatchlistItems()
        
        // Remove existing if present (to update)
        items.removeAll { $0.movieId == item.movieId }
        
        // Add new item
        items.append(item)
        
        persistWatchlistItems(items)
    }
    
    func removeWatchlistItem(movieId: Int) {
        var items = getWatchlistItems()
        items.removeAll { $0.movieId == movieId }
        persistWatchlistItems(items)
    }
    
    func updateWatchedStatus(movieId: Int, isWatched: Bool) {
        var items = getWatchlistItems()
        guard let index = items.firstIndex(where: { $0.movieId == movieId }) else {
            return
        }
        items[index].isWatched = isWatched
        persistWatchlistItems(items)
    }
    
    func getWatchlistStatus(movieId: Int) -> (isInWatchlist: Bool, isWatched: Bool) {
        let items = getWatchlistItems()
        guard let item = items.first(where: { $0.movieId == movieId }) else {
            return (isInWatchlist: false, isWatched: false)
        }
        return (isInWatchlist: true, isWatched: item.isWatched)
    }
    
    // MARK: - Search History
    
    func getSearchHistory() -> [String] {
        return userDefaults.array(forKey: Keys.searchHistory) as? [String] ?? []
    }
    
    func addSearchQuery(_ query: String) {
        var history = getSearchHistory()
        
        // Remove if already exists (to move to top)
        history.removeAll { $0.lowercased() == query.lowercased() }
        
        // Add to beginning
        history.insert(query, at: 0)
        
        // Keep only last 10 searches
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        
        userDefaults.set(history, forKey: Keys.searchHistory)
    }
    
    func clearSearchHistory() {
        userDefaults.removeObject(forKey: Keys.searchHistory)
    }
    
    // MARK: - Private
    
    private func persistWatchlistItems(_ items: [PersistedWatchlistItem]) {
        do {
            let data = try encoder.encode(items)
            userDefaults.set(data, forKey: Keys.watchlistItems)
        } catch {
            // Silently fail - persistence error shouldn't crash the app
        }
    }
}
