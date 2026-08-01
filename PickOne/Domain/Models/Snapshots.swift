//
//  Snapshots.swift
//  PickOne
//
//  Immutable snapshots for Presentation layer
//  Self-sufficient, require no additional fetching
//

import Foundation

// MARK: - DiscoverySnapshot

struct DiscoverySnapshot: Equatable, Sendable {
    let movies: [MovieSummary]
    let currentPage: Int
    let hasMorePages: Bool
    let asOf: Date

    static let empty = DiscoverySnapshot(
        movies: [],
        currentPage: 0,
        hasMorePages: false,
        asOf: Date()
    )
}

// MARK: - MovieDetailSnapshot

struct MovieDetailSnapshot: Equatable, Sendable {
    let movie: Movie
    let similar: [MovieSummary]
    let isInWatchlist: Bool
    let isWatched: Bool
    let director: Person?
    let topCast: [Person]
    let isSimilarUnavailable: Bool
    let isCreditsUnavailable: Bool
    let asOf: Date
}

// MARK: - WatchlistSnapshot

struct WatchlistSnapshot: Equatable, Sendable {
    let toWatch: [WatchlistItem]
    let watched: [WatchlistItem]
    let asOf: Date

    static let empty = WatchlistSnapshot(
        toWatch: [],
        watched: [],
        asOf: Date()
    )
}

// MARK: - ChatRecommendationSnapshot

struct ChatRecommendationSnapshot: Equatable, Sendable {
    let query: String
    let recommendations: [Recommendation]
    let explanation: String
    let asOf: Date
}

struct RecommendationCandidate: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String?
    let year: Int?
    let reason: String?
}

// MARK: - Recommendation

struct Recommendation: Identifiable, Equatable, Sendable {
    let id: Int
    let movie: MovieSummary
    let reason: String?
}

struct ChatRecommendationCandidateResult: Equatable, Sendable {
    let query: String
    let candidates: [RecommendationCandidate]
    let explanation: String
}

// MARK: - SearchSnapshot

struct SearchSnapshot: Equatable, Sendable {
    let query: String
    let results: [MovieSummary]
    let currentPage: Int
    let totalPages: Int
    let asOf: Date

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    static let empty = SearchSnapshot(
        query: "",
        results: [],
        currentPage: 0,
        totalPages: 0,
        asOf: Date()
    )
}
