import Foundation
@testable import PickOne
import Testing

@Suite("Viewer Movie State reducer tests")
struct ViewerMovieStateReducerTests {
    @Test("assigning a rating implies watched and removes conflicting intent")
    func assignRating() throws {
        let saved = try ViewerMovieStateTestFixtures.state(
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(
            .assignReaction(.loveIt),
            current: saved
        )
        let state = try #require(result.state)

        #expect(state.watchState == .watched)
        #expect(state.preference == .reaction(.loveIt))
        #expect(state.watchlistIntent == nil)
        #expect(state.stateChangedAt == ViewerMovieStateTestFixtures.transitionDate)
        #expect(result.impact == .tasteChanged)
    }

    @Test("changing a rating replaces the current rating")
    func changeRating() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.likeIt)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(
            .assignReaction(.didNotLikeIt),
            current: rated
        )

        #expect(result.state?.preference == .reaction(.didNotLikeIt))
        #expect(result.impact == .tasteChanged)
    }

    @Test("removing a rating preserves watched state")
    func removeRating() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.itWasOkay)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.removeReaction, current: rated)

        #expect(result.state?.watchState == .watched)
        #expect(result.state?.preference == nil)
        #expect(result.impact == .tasteChanged)
    }

    @Test("not interested replaces Watchlist intent on an unwatched movie")
    func setNotInterested() throws {
        let saved = try ViewerMovieStateTestFixtures.state(
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.setNotInterested, current: saved)

        #expect(result.state?.watchState == .unwatched)
        #expect(result.state?.preference == .notInterested)
        #expect(result.state?.watchlistIntent == nil)
        #expect(result.impact == .eligibilityChanged)
    }

    @Test("undoing not interested removes the final empty record")
    func undoNotInterested() throws {
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let result = try ViewerMovieStateTestFixtures.reduce(.removeNotInterested, current: rejected)

        #expect(result.state == nil)
        #expect(result.impact == .eligibilityChanged)
        #expect(!result.metadataChanged)
    }

    @Test("marking watched removes not interested")
    func markRejectedMovieWatched() throws {
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let result = try ViewerMovieStateTestFixtures.reduce(.markWatched, current: rejected)

        #expect(result.state?.watchState == .watched)
        #expect(result.state?.preference == nil)
        #expect(result.impact == .eligibilityChanged)
    }

    @Test("marking watched removes Watchlist intent")
    func markSavedMovieWatched() throws {
        let saved = try ViewerMovieStateTestFixtures.state(
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.markWatched, current: saved)

        #expect(result.state?.watchState == .watched)
        #expect(result.state?.watchlistIntent == nil)
        #expect(result.impact == .eligibilityChanged)
    }

    @Test("marking unwatched removes a rating without restoring Watchlist")
    func markRatedMovieUnwatched() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.loveIt)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.markUnwatched, current: rated)

        #expect(result.state == nil)
        #expect(result.impact == .tasteChanged)
    }

    @Test("marking a watched-only movie unwatched removes its final record")
    func markWatchedOnlyMovieUnwatched() throws {
        let watched = try ViewerMovieStateTestFixtures.state(watchState: .watched)

        let result = try ViewerMovieStateTestFixtures.reduce(.markUnwatched, current: watched)

        #expect(result.state == nil)
        #expect(result.impact == .eligibilityChanged)
    }

    @Test("saving an unwatched movie creates future intent")
    func saveUnwatchedMovie() throws {
        let result = try ViewerMovieStateTestFixtures.reduce(.saveToWatchlist)

        #expect(result.state?.watchState == .unwatched)
        #expect(result.state?.preference == nil)
        #expect(result.state?.watchlistIntent?.addedAt == ViewerMovieStateTestFixtures.transitionDate)
        #expect(result.impact == .watchlistIntentChanged)
    }

    @Test("saving to Watchlist clears not interested")
    func saveRejectedMovie() throws {
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let result = try ViewerMovieStateTestFixtures.reduce(.saveToWatchlist, current: rejected)
        let state = try #require(result.state)

        #expect(state.preference == nil)
        #expect(state.watchlistIntent?.addedAt == ViewerMovieStateTestFixtures.transitionDate)
        #expect(result.impact == .eligibilityChanged)
    }

    @Test("removing Watchlist intent does not change any other meaning")
    func removeWatchlist() throws {
        let saved = try ViewerMovieStateTestFixtures.state(
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.removeFromWatchlist, current: saved)

        #expect(result.state == nil)
        #expect(result.impact == .watchlistIntentChanged)
    }

    @Test("not interested is rejected for watched movies")
    func rejectWatchedMovie() throws {
        let watched = try ViewerMovieStateTestFixtures.state(watchState: .watched)

        #expect(throws: ViewerMovieStateTransitionError.notInterestedRequiresUnwatched) {
            try ViewerMovieStateTestFixtures.reduce(.setNotInterested, current: watched)
        }
    }

    @Test("Watchlist is rejected for watched movies")
    func saveWatchedMovie() throws {
        let watched = try ViewerMovieStateTestFixtures.state(watchState: .watched)

        #expect(throws: ViewerMovieStateTransitionError.watchlistRequiresUnwatched) {
            try ViewerMovieStateTestFixtures.reduce(.saveToWatchlist, current: watched)
        }
    }

    @Test("transition identity must be positive and match current state")
    func transitionIdentity() throws {
        let watched = try ViewerMovieStateTestFixtures.state(watchState: .watched)

        #expect(throws: ViewerMovieStateTransitionError.invalidMovieID) {
            try ViewerMovieStateTestFixtures.reduce(.markWatched, movieID: 0)
        }
        #expect(
            throws: ViewerMovieStateTransitionError.movieIDMismatch(
                expected: watched.movieID,
                actual: 1
            )
        ) {
            try ViewerMovieStateTestFixtures.reduce(
                .markWatched,
                current: watched,
                movieID: 1
            )
        }
    }
}
