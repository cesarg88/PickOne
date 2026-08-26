import Foundation

enum ViewerMovieStateProjections {
    static func reactions(
        from snapshot: ViewerMovieStateSnapshot
    ) -> [Int: MovieReaction] {
        Dictionary(
            uniqueKeysWithValues: snapshot.states.compactMap { state in
                state.reaction.map { (state.movieID, $0) }
            }
        )
    }

    static func recommendationExcludedMovieIDs(
        from snapshot: ViewerMovieStateSnapshot
    ) -> Set<Int> {
        Set(
            snapshot.states.compactMap { state in
                state.watchState.isWatched || state.isNotInterested ? state.movieID : nil
            }
        )
    }

    static func watchlist(
        from snapshot: ViewerMovieStateSnapshot
    ) -> [ViewerMovieState] {
        snapshot.states
            .filter { $0.watchlistIntent != nil }
            .sorted { first, second in
                let firstAddedAt = first.watchlistIntent?.addedAt ?? .distantPast
                let secondAddedAt = second.watchlistIntent?.addedAt ?? .distantPast
                guard firstAddedAt == secondAddedAt else {
                    return firstAddedAt > secondAddedAt
                }
                return first.movieID < second.movieID
            }
    }

    static func watchlistCompatibility(
        from snapshot: ViewerMovieStateSnapshot
    ) -> [ViewerMovieState] {
        snapshot.states
            .filter { $0.watchlistIntent != nil || $0.watchState.isWatched }
            .sorted { first, second in
                let firstDate = first.watchlistIntent?.addedAt ?? first.stateChangedAt
                let secondDate = second.watchlistIntent?.addedAt ?? second.stateChangedAt
                guard firstDate == secondDate else { return firstDate > secondDate }
                return first.movieID < second.movieID
            }
    }

    static func myMovies(
        from snapshot: ViewerMovieStateSnapshot
    ) -> [ViewerMovieState] {
        snapshot.states
            .filter { $0.watchState.isWatched || $0.isNotInterested }
            .sorted { first, second in
                guard first.stateChangedAt == second.stateChangedAt else {
                    return first.stateChangedAt > second.stateChangedAt
                }
                return first.movieID < second.movieID
            }
    }
}
