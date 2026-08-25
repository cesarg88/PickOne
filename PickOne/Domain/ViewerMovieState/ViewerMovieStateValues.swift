import Foundation

enum ViewerMovieStateValidationError: Error, Equatable, Sendable {
    case invalidMovieID
    case emptyTitle
    case reactionRequiresWatched
    case notInterestedRequiresUnwatched
    case watchlistRequiresUnwatched
    case preferenceConflictsWithWatchlist
    case emptyUnwatchedState
}

enum MovieReaction: String, CaseIterable, Equatable, Sendable {
    case loveIt
    case likeIt
    case itWasOkay
    case didNotLikeIt

    var p1Value: Double {
        switch self {
            case .loveIt: 1.00
            case .likeIt: 0.50
            case .itWasOkay: 0.00
            case .didNotLikeIt: -0.75
        }
    }

    var isDirectionalEvidence: Bool {
        switch self {
            case .loveIt, .likeIt, .didNotLikeIt: true
            case .itWasOkay: false
        }
    }

    var isPositiveAnchor: Bool {
        switch self {
            case .loveIt, .likeIt: true
            case .itWasOkay, .didNotLikeIt: false
        }
    }

    var impliesWatched: Bool {
        true
    }
}

enum MoviePreference: Equatable, Sendable {
    case reaction(MovieReaction)
    case notInterested
}

enum MovieWatchState: Equatable, Sendable {
    case unwatched
    case watched

    var isWatched: Bool {
        self == .watched
    }
}

struct WatchlistIntent: Equatable, Sendable {
    let addedAt: Date
}

struct MovieFeedbackMetadata: Equatable, Sendable {
    let title: String
    let releaseYear: Int?
    let posterPath: String?

    init(
        title: String,
        releaseYear: Int?,
        posterPath: String?
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ViewerMovieStateValidationError.emptyTitle
        }

        self.title = title
        self.releaseYear = releaseYear
        self.posterPath = posterPath
    }
}

struct ViewerMovieState: Equatable, Sendable {
    let movieID: Int
    let displayMetadata: MovieFeedbackMetadata
    let watchState: MovieWatchState
    let preference: MoviePreference?
    let watchlistIntent: WatchlistIntent?
    let stateChangedAt: Date

    init(
        movieID: Int,
        displayMetadata: MovieFeedbackMetadata,
        watchState: MovieWatchState,
        preference: MoviePreference?,
        watchlistIntent: WatchlistIntent?,
        stateChangedAt: Date
    ) throws {
        guard movieID > 0 else {
            throw ViewerMovieStateValidationError.invalidMovieID
        }
        if preference != nil, watchlistIntent != nil {
            throw ViewerMovieStateValidationError.preferenceConflictsWithWatchlist
        }
        switch preference {
            case .reaction where watchState != .watched:
                throw ViewerMovieStateValidationError.reactionRequiresWatched
            case .notInterested where watchState != .unwatched:
                throw ViewerMovieStateValidationError.notInterestedRequiresUnwatched
            case .reaction, .notInterested, nil:
                break
        }
        if watchlistIntent != nil, watchState != .unwatched {
            throw ViewerMovieStateValidationError.watchlistRequiresUnwatched
        }
        if watchState == .unwatched, preference == nil, watchlistIntent == nil {
            throw ViewerMovieStateValidationError.emptyUnwatchedState
        }

        self.movieID = movieID
        self.displayMetadata = displayMetadata
        self.watchState = watchState
        self.preference = preference
        self.watchlistIntent = watchlistIntent
        self.stateChangedAt = stateChangedAt
    }

    var reaction: MovieReaction? {
        guard case let .reaction(reaction) = preference else { return nil }
        return reaction
    }

    var isNotInterested: Bool {
        preference == .notInterested
    }
}

struct ViewerStateSnapshotID: Hashable, Sendable {
    let rawValue: UUID
}

enum ViewerMovieStateSnapshotValidationError: Error, Equatable, Sendable {
    case duplicateMovieID(Int)
}

struct ViewerMovieStateSnapshot: Equatable, Sendable {
    let id: ViewerStateSnapshotID
    let states: [ViewerMovieState]

    init(
        id: ViewerStateSnapshotID,
        states: [ViewerMovieState]
    ) throws {
        var movieIDs = Set<Int>()
        for state in states where !movieIDs.insert(state.movieID).inserted {
            throw ViewerMovieStateSnapshotValidationError.duplicateMovieID(state.movieID)
        }

        self.id = id
        self.states = states.sorted { $0.movieID < $1.movieID }
    }

    func state(for movieID: Int) -> ViewerMovieState? {
        states.first { $0.movieID == movieID }
    }
}

enum ViewerMovieStateChangeImpact: Equatable, Sendable {
    case tasteChanged
    case eligibilityChanged
    case watchlistIntentChanged
    case none
}

struct ViewerMovieStateReduction: Equatable, Sendable {
    let state: ViewerMovieState?
    let impact: ViewerMovieStateChangeImpact
    let metadataChanged: Bool
}

struct ViewerMovieStateChange: Equatable, Sendable {
    let state: ViewerMovieState?
    let impact: ViewerMovieStateChangeImpact
    let snapshotID: ViewerStateSnapshotID
}

enum ViewerMovieStateRecoveryReason: Equatable, Sendable {
    case corruptData
    case unsupportedSchema
    case migrationFailure
    case loadFailure
}

enum ViewerMovieStateLoadState: Equatable, Sendable {
    case absent
    case loaded(ViewerMovieStateSnapshot)
    case recovery(ViewerMovieStateRecoveryReason)
}
