//
//  GetWatchlist.swift
//  PickOne
//
//  Use case for retrieving the complete watchlist as a snapshot
//

import Foundation

protocol GetWatchlistUseCase: Sendable {
    /// Retrieves the complete watchlist organized by status
    /// - Returns: A snapshot containing toWatch and watched items
    func execute() -> WatchlistSnapshot
}

final class GetWatchlist: GetWatchlistUseCase, Sendable {
    private let repository: WatchlistRepository

    init(repository: WatchlistRepository) {
        self.repository = repository
    }

    func execute() -> WatchlistSnapshot {
        let allItems = repository.getAllItems()

        let toWatch = allItems.filter { !$0.isWatched }
        let watched = allItems.filter { $0.isWatched }

        return WatchlistSnapshot(
            toWatch: toWatch,
            watched: watched,
            asOf: Date()
        )
    }
}
