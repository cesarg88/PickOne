//
//  LocalStore.swift
//  PickOne
//
//  Local persistence for user state (watchlist, watched status, ordering)
//

import Foundation
import Synchronization

// MARK: - Persisted Models

/// Persisted watchlist item with embedded movie summary for offline access
struct PersistedWatchlistItem: Codable, Equatable, Sendable {
    let movieId: Int
    let title: String
    let posterPath: String?
    let releaseYear: Int?
    let rating: Double
    let addedAt: Date
    var isWatched: Bool
}

// MARK: - Store

protocol LocalStore: Sendable {
    // Watchlist with persisted summaries
    func getWatchlistItems() -> [PersistedWatchlistItem]
    func saveWatchlistItem(_ item: PersistedWatchlistItem) throws
    func removeWatchlistItem(movieId: Int) throws
    func updateWatchedStatus(movieId: Int, isWatched: Bool) throws
    func getWatchlistStatus(movieId: Int) -> (isInWatchlist: Bool, isWatched: Bool)

    // Search history
    func getSearchHistory() -> [String]
    func addSearchQuery(_ query: String)
    func clearSearchHistory()
}

final class UserDefaultsLocalStore: LocalStore {
    private enum Backend: Sendable {
        case standard
        case suite(String)

        func makeUserDefaults() -> UserDefaults {
            switch self {
            case .standard:
                return .standard
            case .suite(let name):
                guard let userDefaults = UserDefaults(suiteName: name) else {
                    preconditionFailure("Invalid UserDefaults suite name: \(name)")
                }
                return userDefaults
            }
        }
    }

    private let backend: Mutex<Backend>
    
    private enum Keys {
        static let watchlistItems = "watchlist_items_v2"
        static let searchHistory = "search_history"
    }
    
    init() {
        self.backend = Mutex(.standard)
    }

    init(suiteName: String) {
        self.backend = Mutex(.suite(suiteName))
    }
    
    // MARK: - Watchlist Items
    
    func getWatchlistItems() -> [PersistedWatchlistItem] {
        backend.withLock { backend in
            (try? Self.loadWatchlistItems(from: backend.makeUserDefaults())) ?? []
        }
    }
    
    func saveWatchlistItem(_ item: PersistedWatchlistItem) throws {
        try backend.withLock { backend in
            let userDefaults = backend.makeUserDefaults()
            var items = try Self.loadWatchlistItems(from: userDefaults)

            // Remove existing if present (to update)
            items.removeAll { $0.movieId == item.movieId }

            // Add new item
            items.append(item)

            try Self.persistWatchlistItems(items, to: userDefaults)
        }
    }
    
    func removeWatchlistItem(movieId: Int) throws {
        try backend.withLock { backend in
            let userDefaults = backend.makeUserDefaults()
            var items = try Self.loadWatchlistItems(from: userDefaults)
            items.removeAll { $0.movieId == movieId }
            try Self.persistWatchlistItems(items, to: userDefaults)
        }
    }
    
    func updateWatchedStatus(movieId: Int, isWatched: Bool) throws {
        try backend.withLock { backend in
            let userDefaults = backend.makeUserDefaults()
            var items = try Self.loadWatchlistItems(from: userDefaults)
            guard let index = items.firstIndex(where: { $0.movieId == movieId }) else {
                return
            }
            items[index].isWatched = isWatched
            try Self.persistWatchlistItems(items, to: userDefaults)
        }
    }
    
    func getWatchlistStatus(movieId: Int) -> (isInWatchlist: Bool, isWatched: Bool) {
        backend.withLock { backend in
            let items = (try? Self.loadWatchlistItems(from: backend.makeUserDefaults())) ?? []
            guard let item = items.first(where: { $0.movieId == movieId }) else {
                return (isInWatchlist: false, isWatched: false)
            }
            return (isInWatchlist: true, isWatched: item.isWatched)
        }
    }
    
    // MARK: - Search History
    
    func getSearchHistory() -> [String] {
        backend.withLock { backend in
            Self.loadSearchHistory(from: backend.makeUserDefaults())
        }
    }
    
    func addSearchQuery(_ query: String) {
        backend.withLock { backend in
            let userDefaults = backend.makeUserDefaults()
            var history = Self.loadSearchHistory(from: userDefaults)

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
    }
    
    func clearSearchHistory() {
        backend.withLock { backend in
            backend.makeUserDefaults().removeObject(forKey: Keys.searchHistory)
        }
    }
    
    // MARK: - Private
    
    private static func loadWatchlistItems(from userDefaults: UserDefaults) throws
        -> [PersistedWatchlistItem] {
        guard let data = userDefaults.data(forKey: Keys.watchlistItems) else {
            return []
        }
        do {
            let items = try JSONDecoder().decode([PersistedWatchlistItem].self, from: data)
            // Return sorted by addedAt descending (most recent first)
            return items.sorted { $0.addedAt > $1.addedAt }
        } catch {
            throw LocalStoreError.corruptedWatchlist
        }
    }

    private static func persistWatchlistItems(
        _ items: [PersistedWatchlistItem],
        to userDefaults: UserDefaults
    ) throws {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: Keys.watchlistItems)
        } catch {
            throw LocalStoreError.encodingFailed
        }
    }

    private static func loadSearchHistory(from userDefaults: UserDefaults) -> [String] {
        userDefaults.array(forKey: Keys.searchHistory) as? [String] ?? []
    }
}

enum LocalStoreError: Error, LocalizedError, Equatable {
    case corruptedWatchlist
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .corruptedWatchlist:
            return "Saved watchlist data could not be read. Your existing data was preserved."
        case .encodingFailed:
            return "The watchlist could not be saved. Please try again."
        }
    }
}
