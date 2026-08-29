//
//  LocalStore.swift
//  PickOne
//
//  Local persistence for search history
//

import Foundation
import Synchronization

// MARK: - Store

protocol LocalStore: Sendable {
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
                case let .suite(name):
                    guard let userDefaults = UserDefaults(suiteName: name) else {
                        preconditionFailure("Invalid UserDefaults suite name: \(name)")
                    }
                    return userDefaults
            }
        }
    }

    private let backend: Mutex<Backend>

    private enum Keys {
        static let searchHistory = "search_history"
    }

    init() {
        backend = Mutex(.standard)
    }

    init(suiteName: String) {
        backend = Mutex(.suite(suiteName))
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

    private static func loadSearchHistory(from userDefaults: UserDefaults) -> [String] {
        userDefaults.array(forKey: Keys.searchHistory) as? [String] ?? []
    }
}
