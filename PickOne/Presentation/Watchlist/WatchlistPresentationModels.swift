//
//  WatchlistPresentationModels.swift
//  PickOne
//
//  Presentation models for the Watchlist screen
//

import Foundation

// MARK: - Filter

enum WatchlistFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case toWatch = "To Watch"
    case watched = "Watched"

    var id: String {
        rawValue
    }
}

// MARK: - Presentation Model

struct WatchlistPresentationModel: Equatable {
    let items: [WatchlistItemPresentation]
    let filter: WatchlistFilter

    var isEmpty: Bool {
        items.isEmpty
    }

    static let empty = WatchlistPresentationModel(items: [], filter: .all)
}

struct WatchlistItemPresentation: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
    let releaseYear: String?
    let rating: String
    let isWatched: Bool
    let addedDate: String

    /// The MovieSummary for passing to use cases
    let movieSummary: MovieSummary
}

// MARK: - Mapper

@MainActor
enum WatchlistPresentationMapper {
    static func map(snapshot: WatchlistSnapshot, filter: WatchlistFilter) -> WatchlistPresentationModel {
        let items: [WatchlistItem] = switch filter {
            case .all:
                snapshot.toWatch + snapshot.watched
            case .toWatch:
                snapshot.toWatch
            case .watched:
                snapshot.watched
        }

        // Sort by addedAt descending (most recent first)
        let sorted = items.sorted { $0.addedAt > $1.addedAt }

        return WatchlistPresentationModel(
            items: sorted.map(mapItem),
            filter: filter
        )
    }

    private static func mapItem(_ item: WatchlistItem) -> WatchlistItemPresentation {
        WatchlistItemPresentation(
            id: item.id,
            title: item.movie.title,
            posterURL: posterURL(for: item.movie.posterPath),
            releaseYear: item.movie.releaseYear.map(String.init),
            rating: String(format: "%.1f", item.movie.rating),
            isWatched: item.isWatched,
            addedDate: formatDate(item.addedAt),
            movieSummary: item.movie
        )
    }

    private static func posterURL(for path: String?) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
