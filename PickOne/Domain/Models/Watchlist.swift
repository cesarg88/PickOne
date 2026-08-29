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
    let movie: MovieSummary

    nonisolated init(
        id: Int,
        addedAt: Date,
        movie: MovieSummary
    ) {
        self.id = id
        self.addedAt = addedAt
        self.movie = movie
    }
}

// MARK: - WatchlistStatus

enum WatchlistStatus: Equatable, Sendable {
    case notInWatchlist
    case toWatch
}

struct WatchlistMutationOutcome: Equatable, Sendable {
    let status: WatchlistStatus
    let didChange: Bool
}
