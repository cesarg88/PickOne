//
//  SetWatched.swift
//  PickOne
//
//  Use case for updating the watched status of a movie
//

import Foundation

protocol SetWatchedUseCase: Sendable {
    /// Sets the watched status of a movie in the watchlist
    /// - Parameters:
    ///   - movieId: The ID of the movie
    ///   - isWatched: True if watched, false if to-watch
    /// - Throws: WatchlistError if movie is not in watchlist
    /// - Returns: Whether watched state changed.
    @discardableResult
    func execute(movieId: Int, isWatched: Bool) async throws -> Bool
}

final class SetWatched: SetWatchedUseCase, Sendable {
    private let repository: WatchlistRepository

    init(repository: WatchlistRepository) {
        self.repository = repository
    }

    func execute(movieId: Int, isWatched: Bool) async throws -> Bool {
        let currentStatus = try await repository.getStatus(movieId: movieId)

        guard currentStatus != .notInWatchlist else {
            throw WatchlistError.movieNotInWatchlist
        }

        let alreadyInDesiredState = (isWatched && currentStatus == .watched) ||
            (!isWatched && currentStatus == .toWatch)
        if alreadyInDesiredState {
            return false
        }

        try await repository.setWatched(movieId: movieId, isWatched: isWatched)
        return true
    }
}
