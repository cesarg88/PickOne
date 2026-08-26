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
    /// Returns all items or throws when persisted Watchlist evidence is unreadable.
    func loadAllItems() async throws -> [WatchlistItem]

    /// Adds a movie to the watchlist with its summary for offline persistence
    /// - Parameter movie: The movie summary to add
    func add(movie: MovieSummary) async throws

    /// Removes a movie from the watchlist
    /// - Parameter movieId: The ID of the movie to remove
    func remove(movieId: Int) async throws

    /// Updates the watched status of a movie
    /// - Parameters:
    ///   - movieId: The ID of the movie
    ///   - isWatched: Whether the movie has been watched
    func setWatched(movieId: Int, isWatched: Bool) async throws

    /// Gets the current watchlist status of a movie
    /// - Parameter movieId: The ID of the movie
    /// - Returns: The watchlist status
    func getStatus(movieId: Int) async throws -> WatchlistStatus
}

// MARK: - Errors

enum WatchlistError: Error, LocalizedError, Sendable {
    case movieAlreadyInWatchlist
    case movieNotInWatchlist

    var errorDescription: String? {
        switch self {
            case .movieAlreadyInWatchlist:
                "Movie is already in watchlist"
            case .movieNotInWatchlist:
                "Movie is not in watchlist"
        }
    }
}
