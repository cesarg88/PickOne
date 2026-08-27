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
    /// - Returns: The atomically persisted compatibility outcome.
    @discardableResult
    func execute(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) async throws -> WatchlistMutationOutcome
}

final class SetWatchlistMembership: SetWatchlistMembershipUseCase, Sendable {
    private let repository: WatchlistRepository

    init(repository: WatchlistRepository) {
        self.repository = repository
    }

    func execute(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) async throws -> WatchlistMutationOutcome {
        try await repository.setMembership(
            movie: movie,
            isInWatchlist: isInWatchlist
        )
    }
}
