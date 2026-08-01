//
//  SetWatchlistMembership.swift
//  PickOne
//
//  Use case for adding or removing a movie from the watchlist
//

import Foundation

protocol SetWatchlistMembershipUseCase: Sendable {
    /// Sets whether a movie is in the watchlist
    /// - Parameters:
    ///   - movie: The movie summary (required for adding)
    ///   - isInWatchlist: True to add, false to remove
    func execute(movie: MovieSummary, isInWatchlist: Bool) throws
}

final class SetWatchlistMembership: SetWatchlistMembershipUseCase, Sendable {
    private let repository: WatchlistRepository

    init(repository: WatchlistRepository) {
        self.repository = repository
    }

    func execute(movie: MovieSummary, isInWatchlist: Bool) throws {
        if isInWatchlist {
            // Check if already in watchlist - if so, silently succeed (idempotent)
            let currentStatus = repository.getStatus(movieId: movie.id)
            if currentStatus != .notInWatchlist {
                return
            }
            try repository.add(movie: movie)
        } else {
            // Check if not in watchlist - if so, silently succeed (idempotent)
            let currentStatus = repository.getStatus(movieId: movie.id)
            if currentStatus == .notInWatchlist {
                return
            }
            try repository.remove(movieId: movie.id)
        }
    }
}
