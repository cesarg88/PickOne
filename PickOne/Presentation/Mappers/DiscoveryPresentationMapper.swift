import Foundation

@MainActor
enum DiscoveryPresentationMapper {
    static func map(snapshot: DiscoverySnapshot) -> MovieSummaryPresentationModel {
        MovieSummaryPresentationModel(
            movies: snapshot.movies.map(mapMovie),
            currentPage: snapshot.currentPage,
            hasMorePages: snapshot.hasMorePages,
            isLoadingNextPage: false
        )
    }

    private static func mapMovie(_ summary: MovieSummary) -> DiscoveryMovieItem {
        DiscoveryMovieItem(
            id: summary.id,
            title: summary.title,
            posterURL: ImageURLBuilder.posterURL(path: summary.posterPath, size: .posterMedium),
            releaseYearText: summary.releaseYear.map(String.init),
            ratingText: String(format: "%.1f", summary.rating)
        )
    }
}
