import Foundation

extension LocalViewerStateRepository {
    func loadWatchlistProjection() throws -> [WatchlistItem] {
        try ViewerMovieStateProjections.watchlist(from: snapshot()).map { state in
            WatchlistItem(
                id: state.movieID,
                addedAt: state.watchlistIntent?.addedAt ?? .distantPast,
                isWatched: false,
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

    func watchlistStatus(movieID: Int) throws -> WatchlistStatus {
        guard movieID > 0 else { return .notInWatchlist }
        guard let state = try state(movieID: movieID) else { return .notInWatchlist }
        if state.watchState.isWatched { return .watched }
        return state.watchlistIntent == nil ? .notInWatchlist : .toWatch
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

    func setWatchlistWatched(
        movieID: Int,
        isWatched: Bool
    ) throws -> WatchlistMutationOutcome {
        guard try watchlistStatus(movieID: movieID) != .notInWatchlist,
              let state = try state(movieID: movieID)
        else {
            throw WatchlistError.movieNotInWatchlist
        }
        let change = try apply(
            ViewerMovieStateTransition(
                movieID: movieID,
                action: isWatched ? .markWatched : .markUnwatched
            ),
            metadata: state.displayMetadata
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
        guard let state else { return .notInWatchlist }
        if state.watchState.isWatched { return .watched }
        return state.watchlistIntent == nil ? .notInWatchlist : .toWatch
    }
}
