//
//  WatchlistTestFixtures.swift
//  PickOneTests
//
//  Test fixtures for watchlist-related tests
//

import Foundation
@testable import PickOne

enum WatchlistTestFixtures {
    // MARK: - MovieSummary

    static let movieSummary = MovieSummary(
        id: 1,
        title: "Test Movie",
        posterPath: "/poster.jpg",
        releaseYear: 2024,
        rating: 8.5
    )

    static let anotherMovieSummary = MovieSummary(
        id: 2,
        title: "Another Movie",
        posterPath: "/poster2.jpg",
        releaseYear: 2023,
        rating: 7.0
    )

    // MARK: - WatchlistItem

    static let unwatchedItem = WatchlistItem(
        id: 1,
        addedAt: Date(),
        movie: movieSummary
    )

    static let anotherUnwatchedItem = WatchlistItem(
        id: 2,
        addedAt: Date().addingTimeInterval(-3600),
        movie: anotherMovieSummary
    )

    static let twoItems: [WatchlistItem] = [unwatchedItem, anotherUnwatchedItem]
}
