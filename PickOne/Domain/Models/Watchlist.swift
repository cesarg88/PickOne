//
//  Watchlist.swift
//  PickOne
//
//  Watchlist domain models
//

import Foundation

// MARK: - WatchlistItem

struct WatchlistItem: Identifiable, Equatable {
    let id: Int // Movie ID
    let addedAt: Date
    let isWatched: Bool
    let movie: MovieSummary
    
    init(id: Int, addedAt: Date, isWatched: Bool, movie: MovieSummary) {
        self.id = id
        self.addedAt = addedAt
        self.isWatched = isWatched
        self.movie = movie
    }
}

// MARK: - WatchlistStatus

enum WatchlistStatus {
    case notInWatchlist
    case toWatch
    case watched
}
