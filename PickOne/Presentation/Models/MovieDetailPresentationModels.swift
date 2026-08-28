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
}

struct MovieFeedbackPresentationModel: Equatable {
    let reaction: MovieReaction?
    let isWatched: Bool
    let isNotInterested: Bool
    let isInWatchlist: Bool
}

enum MovieFeedbackViewState: Equatable {
    case loading
    case loaded(
        MovieFeedbackPresentationModel,
        isSaving: Bool,
        canSubmit: Bool
    )
    case failure(String)
}

struct SimilarMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
}
