//
//  DefaultSearchHistoryRepository.swift
//  PickOne
//
//  Implementation of SearchHistoryRepository using LocalStore
//

import Foundation

final class DefaultSearchHistoryRepository: SearchHistoryRepository {
    private let localStore: LocalStore

    init(localStore: LocalStore) {
        self.localStore = localStore
    }

    // MARK: - SearchHistoryRepository

    func getHistory() -> [String] {
        localStore.getSearchHistory()
    }

    func addQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        localStore.addSearchQuery(trimmed)
    }

    func clear() {
        localStore.clearSearchHistory()
    }
}
