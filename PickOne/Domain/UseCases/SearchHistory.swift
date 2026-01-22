//
//  SearchHistory.swift
//  PickOne
//
//  Use case for managing search history
//

import Foundation

protocol SearchHistoryUseCase: Sendable {
    /// Returns the search history (most recent first)
    func getHistory() -> [String]
    
    /// Clears all search history
    func clear()
}

final class SearchHistory: SearchHistoryUseCase, Sendable {
    
    private let repository: SearchHistoryRepository
    
    init(repository: SearchHistoryRepository) {
        self.repository = repository
    }
    
    func getHistory() -> [String] {
        repository.getHistory()
    }
    
    func clear() {
        repository.clear()
    }
}
