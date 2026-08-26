import Foundation

extension LocalViewerStateRepository {
    func loadWatchlistProjection() throws -> [WatchlistItem] {
        try ViewerMovieStateProjections.watchlistCompatibility(from: snapshot()).map { state in
            WatchlistItem(
                id: state.movieID,
                addedAt: state.watchlistIntent?.addedAt ?? state.stateChangedAt,
                isWatched: state.watchState.isWatched,
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

    func addToWatchlist(movie: MovieSummary) throws {
        guard try watchlistStatus(movieID: movie.id) == .notInWatchlist else {
            throw WatchlistError.movieAlreadyInWatchlist
        }
        _ = try apply(
            ViewerMovieStateTransition(movieID: movie.id, action: .saveToWatchlist),
            metadata: feedbackMetadata(movie)
        )
    }

    func removeFromWatchlist(movieID: Int) throws {
        guard try watchlistStatus(movieID: movieID) != .notInWatchlist else {
            throw WatchlistError.movieNotInWatchlist
        }
        guard let state = try state(movieID: movieID) else {
            throw WatchlistError.movieNotInWatchlist
        }
        _ = try apply(
            ViewerMovieStateTransition(movieID: movieID, action: .removeFromWatchlist),
            metadata: state.displayMetadata
        )
    }

    func setWatchlistWatched(movieID: Int, isWatched: Bool) throws {
        guard try watchlistStatus(movieID: movieID) != .notInWatchlist,
              let state = try state(movieID: movieID)
        else {
            throw WatchlistError.movieNotInWatchlist
        }
        _ = try apply(
            ViewerMovieStateTransition(
                movieID: movieID,
                action: isWatched ? .markWatched : .markUnwatched
            ),
            metadata: state.displayMetadata
        )
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
}
