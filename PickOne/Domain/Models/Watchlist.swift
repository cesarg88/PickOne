//
//  Watchlist.swift
//  PickOne
//
//  Watchlist domain models
//

import Foundation

// MARK: - WatchlistItem

struct WatchlistItem: Identifiable, Equatable, Sendable {
    let id: Int // Movie ID
    let addedAt: Date
    let isWatched: Bool
    let movie: MovieSummary

    nonisolated init(
        id: Int,
        addedAt: Date,
        isWatched: Bool,
        movie: MovieSummary
    ) {
        self.id = id
        self.addedAt = addedAt
        self.isWatched = isWatched
        self.movie = movie
    }
}

// MARK: - WatchlistStatus

enum WatchlistStatus: Equatable, Sendable {
    case notInWatchlist
    case toWatch
    case watched
}
