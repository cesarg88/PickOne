import Foundation

struct MovieSummaryPresentationModel: Equatable {
    let movies: [DiscoveryMovieItem]
    let currentPage: Int
    let hasMorePages: Bool
    var isLoadingNextPage: Bool
}

struct DiscoveryMovieItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let posterURL: URL?
    let releaseYearText: String?
    let ratingText: String
}
