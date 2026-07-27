//
//  WatchlistItemMapper.swift
//  PickOne
//
//  Maps between persistence and domain watchlist models
//

import Foundation

enum WatchlistItemMapper: Sendable {
    
    /// Maps a persisted watchlist item to a domain WatchlistItem
    nonisolated static func toDomain(_ persisted: PersistedWatchlistItem) -> WatchlistItem {
        let movie = MovieSummary(
            id: persisted.movieId,
            title: persisted.title,
            posterPath: persisted.posterPath,
            releaseYear: persisted.releaseYear,
            rating: persisted.rating
        )
        
        return WatchlistItem(
            id: persisted.movieId,
            addedAt: persisted.addedAt,
            isWatched: persisted.isWatched,
            movie: movie
        )
    }
    
    /// Creates a persisted watchlist item from a movie summary
    nonisolated static func toPersisted(
        movie: MovieSummary,
        addedAt: Date = Date()
    ) -> PersistedWatchlistItem {
        PersistedWatchlistItem(
            movieId: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
            releaseYear: movie.releaseYear,
            rating: movie.rating,
            addedAt: addedAt,
            isWatched: false
        )
    }
}
