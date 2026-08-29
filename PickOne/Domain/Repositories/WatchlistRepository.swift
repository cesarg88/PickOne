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

    /// Atomically sets Watchlist intent and returns the persisted outcome.
    func setMembership(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) async throws -> WatchlistMutationOutcome
}
