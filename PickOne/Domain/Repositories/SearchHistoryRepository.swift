//
//  SearchHistoryRepository.swift
//  PickOne
//
//  Protocol for search history management (domain layer)
//

import Foundation

/// Repository for managing search history
protocol SearchHistoryRepository: Sendable {
    /// Returns the search history (most recent first)
    func getHistory() -> [String]
    
    /// Adds a query to the search history
    /// - Parameter query: The search query to add
    func addQuery(_ query: String)
    
    /// Clears all search history
    func clear()
}
