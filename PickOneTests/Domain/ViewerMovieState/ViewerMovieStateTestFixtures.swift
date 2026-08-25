import Foundation
@testable import PickOne

enum ViewerMovieStateTestFixtures {
    static let initialDate = Date(timeIntervalSince1970: 1000)
    static let transitionDate = Date(timeIntervalSince1970: 2000)
    static let laterDate = Date(timeIntervalSince1970: 3000)

    static func metadata(
        title: String = "Arrival",
        releaseYear: Int? = 2016,
        posterPath: String? = "/arrival.jpg"
    ) throws -> MovieFeedbackMetadata {
        try MovieFeedbackMetadata(
            title: title,
            releaseYear: releaseYear,
            posterPath: posterPath
        )
    }

    static func state(
        movieID: Int = 329_865,
        title: String = "Arrival",
        watchState: MovieWatchState = .unwatched,
        preference: MoviePreference? = nil,
        watchlistIntent: WatchlistIntent? = nil,
        stateChangedAt: Date = initialDate
    ) throws -> ViewerMovieState {
        try ViewerMovieState(
            movieID: movieID,
            displayMetadata: metadata(title: title),
            watchState: watchState,
            preference: preference,
            watchlistIntent: watchlistIntent,
            stateChangedAt: stateChangedAt
        )
    }

    static func reduce(
        _ action: ViewerMovieStateTransition.Action,
        current: ViewerMovieState? = nil,
        movieID: Int = 329_865,
        metadata: MovieFeedbackMetadata? = nil,
        at date: Date = transitionDate
    ) throws -> ViewerMovieStateReduction {
        try ViewerMovieStateReducer.reduce(
            current: current,
            transition: ViewerMovieStateTransition(movieID: movieID, action: action),
            metadata: metadata ?? self.metadata(),
            at: date
        )
    }
}
