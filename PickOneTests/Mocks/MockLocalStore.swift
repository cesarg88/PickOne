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
        var searchHistory: [String] = []
    }

    private let state = Mutex(State())

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

    func reset() {
        state.withLock { $0 = State() }
    }
}
