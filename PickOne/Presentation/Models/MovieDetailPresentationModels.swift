import Foundation

struct MovieDetailPresentationModel: Equatable {
    let title: String
    let releaseYearText: String?
    let runtimeText: String?
    let ratingText: String
    let overview: String
    let backdropURL: URL?
    let similar: [SimilarMovieItem]
    let isSimilarUnavailable: Bool
    let isCreditsUnavailable: Bool
    let directorName: String?
    let topCastNames: [String]
    let isInWatchlist: Bool
    let isWatched: Bool
}

struct SimilarMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
}
