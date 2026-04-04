import Foundation

struct MovieDetailPresentationModel: Equatable {
    let id: Int
    let title: String
    let releaseYear: String?
    let runtimeText: String?
    let rating: String
    let overview: String
    let posterURL: URL?
    let backdropURL: URL?
    let similar: [SimilarMovieItem]
    let isSimilarUnavailable: Bool
    let isCreditsUnavailable: Bool
    let directorName: String?
    let topCastNames: [String]
    var isInWatchlist: Bool
    var isWatched: Bool
}

struct SimilarMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
}
