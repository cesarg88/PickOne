import Foundation

extension LocalViewerStateRepository {
    func loadWatchlistProjection() throws -> [WatchlistItem] {
        try ViewerMovieStateProjections.watchlist(from: snapshot()).map { state in
            WatchlistItem(
                id: state.movieID,
                addedAt: state.watchlistIntent?.addedAt ?? .distantPast,
                movie: MovieSummary(
                    id: state.movieID,
                    title: state.displayMetadata.title,
                    posterPath: state.displayMetadata.posterPath,
                    releaseYear: state.displayMetadata.releaseYear,
                    rating: 0
                )
            )
        }
    }

    func setWatchlistMembership(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) throws -> WatchlistMutationOutcome {
        let change = try apply(
            ViewerMovieStateTransition(
                movieID: movie.id,
                action: isInWatchlist ? .saveToWatchlist : .removeFromWatchlist
            ),
            metadata: feedbackMetadata(movie)
        )
        return watchlistOutcome(change)
    }

    private func feedbackMetadata(_ movie: MovieSummary) throws -> MovieFeedbackMetadata {
        do {
            return try MovieFeedbackMetadata(
                title: movie.title,
                releaseYear: movie.releaseYear,
                posterPath: movie.posterPath
            )
        } catch {
            throw ViewerMovieStateRepositoryError.corruptData
        }
    }

    private func watchlistOutcome(
        _ change: ViewerMovieStateChange
    ) -> WatchlistMutationOutcome {
        WatchlistMutationOutcome(
            status: watchlistStatus(change.state),
            didChange: change.impact != .none
        )
    }

    private func watchlistStatus(_ state: ViewerMovieState?) -> WatchlistStatus {
        state?.watchlistIntent == nil ? .notInWatchlist : .toWatch
    }
}
