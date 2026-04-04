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
    func execute(movieId: Int, isWatched: Bool) throws
}

final class SetWatched: SetWatchedUseCase, Sendable {
    
    private let repository: WatchlistRepository
    
    init(repository: WatchlistRepository) {
        self.repository = repository
    }
    
    func execute(movieId: Int, isWatched: Bool) throws {
        let currentStatus = repository.getStatus(movieId: movieId)
        
        guard currentStatus != .notInWatchlist else {
            throw WatchlistError.movieNotInWatchlist
        }
        
        // Check if already in desired state - if so, silently succeed (idempotent)
        let alreadyInDesiredState = (isWatched && currentStatus == .watched) ||
                                     (!isWatched && currentStatus == .toWatch)
        if alreadyInDesiredState {
            return
        }
        
        try repository.setWatched(movieId: movieId, isWatched: isWatched)
    }
}
