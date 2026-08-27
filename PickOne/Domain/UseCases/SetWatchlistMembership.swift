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
    /// - Returns: Whether Watchlist intent changed.
    @discardableResult
    func execute(movie: MovieSummary, isInWatchlist: Bool) async throws -> Bool
}

final class SetWatchlistMembership: SetWatchlistMembershipUseCase, Sendable {
    private let repository: WatchlistRepository

    init(repository: WatchlistRepository) {
        self.repository = repository
    }

    func execute(movie: MovieSummary, isInWatchlist: Bool) async throws -> Bool {
        if isInWatchlist {
            let currentStatus = try await repository.getStatus(movieId: movie.id)
            if currentStatus != .notInWatchlist {
                return false
            }
            try await repository.add(movie: movie)
            return true
        } else {
            let currentStatus = try await repository.getStatus(movieId: movie.id)
            if currentStatus != .toWatch {
                return false
            }
            try await repository.remove(movieId: movie.id)
            return true
        }
    }
}
