import Foundation

struct ViewerMovieStateTransition: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case assignReaction(MovieReaction)
        case removeReaction
        case setNotInterested
        case removeNotInterested
        case markWatched
        case markUnwatched
        case saveToWatchlist
        case removeFromWatchlist
    }

    let movieID: Int
    let action: Action
}

enum ViewerMovieStateTransitionError: Error, Equatable, Sendable {
    case invalidMovieID
    case movieIDMismatch(expected: Int, actual: Int)
    case notInterestedRequiresUnwatched
    case watchlistRequiresUnwatched
}

enum ViewerMovieStateReducer {
    static func reduce(
        current: ViewerMovieState?,
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata,
        at date: Date
    ) throws -> ViewerMovieStateReduction {
        try validateIdentity(current: current, movieID: transition.movieID)

        let previousSemanticState = SemanticState(current)
        var nextSemanticState = previousSemanticState

        switch transition.action {
            case let .assignReaction(reaction):
                nextSemanticState.watchState = .watched
                nextSemanticState.preference = .reaction(reaction)
                nextSemanticState.watchlistIntent = nil
            case .removeReaction:
                if case .reaction = nextSemanticState.preference {
                    nextSemanticState.preference = nil
                }
            case .setNotInterested:
                guard nextSemanticState.watchState == .unwatched else {
                    throw ViewerMovieStateTransitionError.notInterestedRequiresUnwatched
                }
                nextSemanticState.preference = .notInterested
                nextSemanticState.watchlistIntent = nil
            case .removeNotInterested:
                if nextSemanticState.preference == .notInterested {
                    nextSemanticState.preference = nil
                }
            case .markWatched:
                nextSemanticState.watchState = .watched
                if nextSemanticState.preference == .notInterested {
                    nextSemanticState.preference = nil
                }
                nextSemanticState.watchlistIntent = nil
            case .markUnwatched:
                nextSemanticState.watchState = .unwatched
                if case .reaction = nextSemanticState.preference {
                    nextSemanticState.preference = nil
                }
            case .saveToWatchlist:
                guard nextSemanticState.watchState == .unwatched else {
                    throw ViewerMovieStateTransitionError.watchlistRequiresUnwatched
                }
                if nextSemanticState.preference == .notInterested {
                    nextSemanticState.preference = nil
                }
                if nextSemanticState.watchlistIntent == nil {
                    nextSemanticState.watchlistIntent = WatchlistIntent(addedAt: date)
                }
            case .removeFromWatchlist:
                nextSemanticState.watchlistIntent = nil
        }

        let impact = impact(from: previousSemanticState, to: nextSemanticState)
        let stateChangedAt = impact == .none ? current?.stateChangedAt : date
        let nextState = try makeState(
            movieID: transition.movieID,
            metadata: metadata,
            semanticState: nextSemanticState,
            stateChangedAt: stateChangedAt
        )

        return ViewerMovieStateReduction(
            state: nextState,
            impact: impact,
            metadataChanged: metadataChanged(from: current, to: nextState)
        )
    }

    static func reduceCalibrationResponse(
        current: ViewerMovieState?,
        movieID: Int,
        response: CalibrationReaction,
        metadata: MovieFeedbackMetadata,
        at date: Date
    ) throws -> ViewerMovieStateReduction {
        try validateIdentity(current: current, movieID: movieID)
        guard let reaction = MovieReaction(response) else {
            return ViewerMovieStateReduction(
                state: current,
                impact: .none,
                metadataChanged: false
            )
        }

        return try reduce(
            current: current,
            transition: ViewerMovieStateTransition(
                movieID: movieID,
                action: .assignReaction(reaction)
            ),
            metadata: metadata,
            at: date
        )
    }

    private static func validateIdentity(
        current: ViewerMovieState?,
        movieID: Int
    ) throws {
        guard movieID > 0 else {
            throw ViewerMovieStateTransitionError.invalidMovieID
        }
        if let current, current.movieID != movieID {
            throw ViewerMovieStateTransitionError.movieIDMismatch(
                expected: current.movieID,
                actual: movieID
            )
        }
    }

    private static func makeState(
        movieID: Int,
        metadata: MovieFeedbackMetadata,
        semanticState: SemanticState,
        stateChangedAt: Date?
    ) throws -> ViewerMovieState? {
        if semanticState.isEmpty {
            return nil
        }

        guard let stateChangedAt else {
            return nil
        }
        return try ViewerMovieState(
            movieID: movieID,
            displayMetadata: metadata,
            watchState: semanticState.watchState,
            preference: semanticState.preference,
            watchlistIntent: semanticState.watchlistIntent,
            stateChangedAt: stateChangedAt
        )
    }

    private static func impact(
        from previous: SemanticState,
        to next: SemanticState
    ) -> ViewerMovieStateChangeImpact {
        if previous.reaction != next.reaction {
            return .tasteChanged
        }
        if previous.watchState != next.watchState || previous.isNotInterested != next.isNotInterested {
            return .eligibilityChanged
        }
        if previous.watchlistIntent != next.watchlistIntent {
            return .watchlistIntentChanged
        }
        return .none
    }

    private static func metadataChanged(
        from current: ViewerMovieState?,
        to next: ViewerMovieState?
    ) -> Bool {
        guard let current, let next else { return false }
        return current.displayMetadata != next.displayMetadata
    }
}

private extension MovieReaction {
    init?(_ response: CalibrationReaction) {
        switch response {
            case .loveIt: self = .loveIt
            case .likeIt: self = .likeIt
            case .itWasOkay: self = .itWasOkay
            case .didNotLikeIt: self = .didNotLikeIt
            case .haveNotSeenIt, .doNotKnowIt: return nil
        }
    }
}

private struct SemanticState: Equatable {
    var watchState: MovieWatchState
    var preference: MoviePreference?
    var watchlistIntent: WatchlistIntent?

    init(_ state: ViewerMovieState?) {
        watchState = state?.watchState ?? .unwatched
        preference = state?.preference
        watchlistIntent = state?.watchlistIntent
    }

    var reaction: MovieReaction? {
        guard case let .reaction(reaction) = preference else { return nil }
        return reaction
    }

    var isNotInterested: Bool {
        preference == .notInterested
    }

    var isEmpty: Bool {
        watchState == .unwatched && preference == nil && watchlistIntent == nil
    }
}
