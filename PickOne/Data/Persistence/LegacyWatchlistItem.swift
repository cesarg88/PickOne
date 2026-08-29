import Foundation

/// Read-only M6 Watchlist payload retained for migration and recovery.
struct PersistedWatchlistItem: Codable, Equatable, Sendable {
    let movieId: Int
    let title: String
    let posterPath: String?
    let releaseYear: Int?
    let rating: Double
    let addedAt: Date
    let isWatched: Bool
}
