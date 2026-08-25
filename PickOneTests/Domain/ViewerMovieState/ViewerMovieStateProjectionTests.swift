import Foundation
@testable import PickOne
import Testing

@Suite("Viewer Movie State projection tests")
struct ViewerMovieStateProjectionTests {
    @Test("each accepted reaction is stored as watched state")
    func reactionCasesAndWatchedMeaning() throws {
        #expect(MovieReaction.allCases == [.loveIt, .likeIt, .itWasOkay, .didNotLikeIt])

        for reaction in MovieReaction.allCases {
            let result = try ViewerMovieStateTestFixtures.reduce(.assignReaction(reaction))

            #expect(result.state?.watchState == .watched)
            #expect(result.state?.preference == .reaction(reaction))
        }
    }

    @Test("not interested is eligibility-only and never Taste evidence")
    func notInterestedProjection() throws {
        let rejected = try ViewerMovieStateTestFixtures.state(
            movieID: 10,
            title: "Rejected",
            preference: .notInterested
        )
        let rated = try ViewerMovieStateTestFixtures.state(
            movieID: 20,
            title: "Rated",
            watchState: .watched,
            preference: .reaction(.likeIt)
        )
        let snapshot = try makeSnapshot(states: [rejected, rated])

        #expect(ViewerMovieStateProjections.reactions(from: snapshot) == [20: .likeIt])
        #expect(ViewerMovieStateProjections.recommendationExcludedMovieIDs(from: snapshot) == [10, 20])
    }

    @Test("Watchlist projection includes future intent only in deterministic order")
    func watchlistProjection() throws {
        let older = try ViewerMovieStateTestFixtures.state(
            movieID: 20,
            title: "Older",
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )
        let newerHighID = try ViewerMovieStateTestFixtures.state(
            movieID: 30,
            title: "Newer high ID",
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.laterDate)
        )
        let newerLowID = try ViewerMovieStateTestFixtures.state(
            movieID: 10,
            title: "Newer low ID",
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.laterDate)
        )
        let watched = try ViewerMovieStateTestFixtures.state(
            movieID: 40,
            title: "Watched",
            watchState: .watched
        )
        let snapshot = try makeSnapshot(states: [older, watched, newerHighID, newerLowID])

        #expect(ViewerMovieStateProjections.watchlist(from: snapshot).map(\.movieID) == [10, 30, 20])
    }

    @Test("My movies contains feedback and watched-only states but no Watchlist-only rows")
    func myMoviesContentAndOrder() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            movieID: 30,
            title: "Rated",
            watchState: .watched,
            preference: .reaction(.loveIt),
            stateChangedAt: ViewerMovieStateTestFixtures.laterDate
        )
        let rejected = try ViewerMovieStateTestFixtures.state(
            movieID: 20,
            title: "Rejected",
            preference: .notInterested,
            stateChangedAt: ViewerMovieStateTestFixtures.laterDate
        )
        let watched = try ViewerMovieStateTestFixtures.state(
            movieID: 40,
            title: "Watched",
            watchState: .watched,
            stateChangedAt: ViewerMovieStateTestFixtures.initialDate
        )
        let saved = try ViewerMovieStateTestFixtures.state(
            movieID: 10,
            title: "Saved",
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )
        let snapshot = try makeSnapshot(states: [saved, watched, rated, rejected])

        #expect(ViewerMovieStateProjections.myMovies(from: snapshot).map(\.movieID) == [20, 30, 40])
    }

    @Test("informative calibration responses upsert reactions")
    func informativeCalibrationUpsert() throws {
        let existing = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.didNotLikeIt)
        )

        let result = try ViewerMovieStateReducer.reduceCalibrationResponse(
            current: existing,
            movieID: existing.movieID,
            response: .loveIt,
            metadata: ViewerMovieStateTestFixtures.metadata(),
            at: ViewerMovieStateTestFixtures.transitionDate
        )

        #expect(result.state?.preference == .reaction(.loveIt))
        #expect(result.impact == .tasteChanged)
    }

    @Test("non-informative calibration responses preserve all historical state")
    func nonInformativeCalibrationNoOp() throws {
        let existing = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.likeIt)
        )

        for response in [CalibrationReaction.haveNotSeenIt, .doNotKnowIt] {
            let result = try ViewerMovieStateReducer.reduceCalibrationResponse(
                current: existing,
                movieID: existing.movieID,
                response: response,
                metadata: ViewerMovieStateTestFixtures.metadata(title: "Refreshed title"),
                at: ViewerMovieStateTestFixtures.transitionDate
            )

            #expect(result.state == existing)
            #expect(result.impact == .none)
            #expect(!result.metadataChanged)
        }
    }

    private func makeSnapshot(states: [ViewerMovieState]) throws -> ViewerMovieStateSnapshot {
        try ViewerMovieStateSnapshot(
            id: ViewerStateSnapshotID(rawValue: UUID()),
            states: states
        )
    }
}
