//
//  LocalStore.swift
//  PickOne
//
//  Local persistence for user state (watchlist, watched status, ordering)
//

import Foundation

protocol LocalStoreProtocol {
    func getWatchlistIDs() -> [Int]
    func saveWatchlistIDs(_ ids: [Int])
    
    func getWatchedIDs() -> Set<Int>
    func addToWatched(movieID: Int)
    func removeFromWatched(movieID: Int)
    
    func getWatchlistOrder() -> [Int]
    func saveWatchlistOrder(_ order: [Int])
    
    func getSearchHistory() -> [String]
    func addSearchQuery(_ query: String)
    func clearSearchHistory()
}

final class UserDefaultsLocalStore: LocalStoreProtocol {
    
    private let userDefaults: UserDefaults
    
    private enum Keys {
        static let watchlistIDs = "watchlist_ids"
        static let watchedIDs = "watched_ids"
        static let watchlistOrder = "watchlist_order"
        static let searchHistory = "search_history"
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Watchlist
    
    func getWatchlistIDs() -> [Int] {
        return userDefaults.array(forKey: Keys.watchlistIDs) as? [Int] ?? []
    }
    
    func saveWatchlistIDs(_ ids: [Int]) {
        userDefaults.set(ids, forKey: Keys.watchlistIDs)
        normalizeWatchlistOrder(with: ids)
    }
    
    // MARK: - Watched
    
    func getWatchedIDs() -> Set<Int> {
        let array = userDefaults.array(forKey: Keys.watchedIDs) as? [Int] ?? []
        return Set(array)
    }
    
    func addToWatched(movieID: Int) {
        var watched = getWatchedIDs()
        watched.insert(movieID)
        userDefaults.set(Array(watched).sorted(), forKey: Keys.watchedIDs)
    }
    
    func removeFromWatched(movieID: Int) {
        var watched = getWatchedIDs()
        watched.remove(movieID)
        userDefaults.set(Array(watched), forKey: Keys.watchedIDs)
    }
    
    // MARK: - Ordering
    
    func getWatchlistOrder() -> [Int] {
        let ids = getWatchlistIDs()
        let order = userDefaults.array(forKey: Keys.watchlistOrder) as? [Int] ?? []
        let normalized = normalizedWatchlistOrder(order: order, ids: ids)
        if normalized != order {
            userDefaults.set(normalized, forKey: Keys.watchlistOrder)
        }
        return normalized
    }
    
    func saveWatchlistOrder(_ order: [Int]) {
        let ids = getWatchlistIDs()
        let normalized = normalizedWatchlistOrder(order: order, ids: ids)
        userDefaults.set(normalized, forKey: Keys.watchlistOrder)
    }
    
    // MARK: - Search History
    
    func getSearchHistory() -> [String] {
        return userDefaults.array(forKey: Keys.searchHistory) as? [String] ?? []
    }
    
    func addSearchQuery(_ query: String) {
        var history = getSearchHistory()
        
        // Remove if already exists (to move to top)
        history.removeAll { $0 == query }
        
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
}

private extension UserDefaultsLocalStore {
    func normalizeWatchlistOrder(with ids: [Int]) {
        let order = userDefaults.array(forKey: Keys.watchlistOrder) as? [Int] ?? []
        let normalized = normalizedWatchlistOrder(order: order, ids: ids)
        if normalized != order {
            userDefaults.set(normalized, forKey: Keys.watchlistOrder)
        }
    }
    
    func normalizedWatchlistOrder(order: [Int], ids: [Int]) -> [Int] {
        let idSet = Set(ids)
        let filtered = order.filter { idSet.contains($0) }
        let missing = ids.filter { !filtered.contains($0) }
        return filtered + missing
    }
}
