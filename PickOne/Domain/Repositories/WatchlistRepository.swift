//
//  WatchlistRepository.swift
//  PickOne
//
//  Protocol for watchlist state management (domain layer)
//

import Foundation

/// Repository for managing watchlist state
/// Returns domain models only - no snapshots or UI models
protocol WatchlistRepository: Sendable {
    /// Returns all watchlist items ordered by date added (most recent first)
    func getAllItems() -> [WatchlistItem]
    
    /// Adds a movie to the watchlist with its summary for offline persistence
    /// - Parameter movie: The movie summary to add
    func add(movie: MovieSummary) throws
    
    /// Removes a movie from the watchlist
    /// - Parameter movieId: The ID of the movie to remove
    func remove(movieId: Int) throws
    
    /// Updates the watched status of a movie
    /// - Parameters:
    ///   - movieId: The ID of the movie
    ///   - isWatched: Whether the movie has been watched
    func setWatched(movieId: Int, isWatched: Bool) throws
    
    /// Gets the current watchlist status of a movie
    /// - Parameter movieId: The ID of the movie
    /// - Returns: The watchlist status
    func getStatus(movieId: Int) -> WatchlistStatus
}

// MARK: - Errors

enum WatchlistError: Error, LocalizedError {
    case movieAlreadyInWatchlist
    case movieNotInWatchlist
    
    var errorDescription: String? {
        switch self {
        case .movieAlreadyInWatchlist:
            return "Movie is already in watchlist"
        case .movieNotInWatchlist:
            return "Movie is not in watchlist"
        }
    }
}
