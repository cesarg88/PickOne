import Foundation

@MainActor
enum MovieDetailPresentationMapper {
    static func map(snapshot: MovieDetailSnapshot) -> MovieDetailPresentationModel {
        let movie = snapshot.movie
        return MovieDetailPresentationModel(
            id: movie.id,
            title: movie.title,
            releaseYear: movie.releaseYear.map(String.init),
            runtimeText: movie.runtimeFormatted,
            rating: formatRating(movie.rating, voteCount: movie.voteCount),
            overview: movie.overview,
            posterURL: ImageURLBuilder.posterURL(path: movie.posterPath, size: .posterMedium),
            backdropURL: ImageURLBuilder.backdropURL(path: movie.backdropPath, size: .backdropLarge),
            similar: snapshot.similar.map { movie in
                SimilarMovieItem(
                    id: movie.id,
                    title: movie.title,
                    posterURL: ImageURLBuilder.posterURL(path: movie.posterPath, size: .posterSmall)
                )
            },
            isSimilarUnavailable: snapshot.isSimilarUnavailable,
            isCreditsUnavailable: snapshot.isCreditsUnavailable,
            directorName: snapshot.director?.name,
            topCastNames: snapshot.topCast.map(\.name),
            isInWatchlist: snapshot.isInWatchlist,
            isWatched: snapshot.isWatched
        )
    }
    
    private static func formatRating(_ rating: Double, voteCount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let votesFormatted = formatter.string(from: NSNumber(value: voteCount)) ?? "\(voteCount)"
        return String(format: "%.1f (%@)", rating, votesFormatted)
    }
}
