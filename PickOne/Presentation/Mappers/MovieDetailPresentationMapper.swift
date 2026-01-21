import Foundation

@MainActor
enum MovieDetailPresentationMapper {
    static func map(snapshot: MovieDetailSnapshot) -> MovieDetailPresentationModel {
        let movie = snapshot.movie
        return MovieDetailPresentationModel(
            title: movie.title,
            releaseYearText: movie.releaseYear.map(String.init),
            runtimeText: movie.runtimeFormatted,
            ratingText: String(format: "%.1f", movie.rating),
            overview: movie.overview,
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
}
