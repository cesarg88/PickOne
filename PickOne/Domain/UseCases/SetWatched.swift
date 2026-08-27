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
    /// - Returns: The atomically persisted compatibility outcome.
    @discardableResult
    func execute(
        movieId: Int,
        isWatched: Bool
    ) async throws -> WatchlistMutationOutcome
}

final class SetWatched: SetWatchedUseCase, Sendable {
    private let repository: WatchlistRepository

    init(repository: WatchlistRepository) {
        self.repository = repository
    }

    func execute(
        movieId: Int,
        isWatched: Bool
    ) async throws -> WatchlistMutationOutcome {
        try await repository.setWatched(movieId: movieId, isWatched: isWatched)
    }
}
