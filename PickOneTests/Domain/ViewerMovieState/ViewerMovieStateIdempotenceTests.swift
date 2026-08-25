import Foundation
@testable import PickOne
import Testing

@Suite("Viewer Movie State idempotence and impact tests")
struct ViewerMovieStateIdempotenceTests {
    @Test("same rating is a semantic no-op")
    func sameRating() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.loveIt)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.assignReaction(.loveIt), current: rated)

        #expect(result.state == rated)
        #expect(result.impact == .none)
        #expect(!result.metadataChanged)
    }

    @Test("already watched is a no-op that preserves the reaction")
    func alreadyWatched() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.likeIt)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(.markWatched, current: rated)

        #expect(result.state == rated)
        #expect(result.impact == .none)
    }

    @Test("repeated Watchlist save preserves addedAt and stateChangedAt")
    func repeatedWatchlistSave() throws {
        let intent = WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        let saved = try ViewerMovieStateTestFixtures.state(watchlistIntent: intent)

        let result = try ViewerMovieStateTestFixtures.reduce(.saveToWatchlist, current: saved)

        #expect(result.state?.watchlistIntent == intent)
        #expect(result.state?.stateChangedAt == ViewerMovieStateTestFixtures.initialDate)
        #expect(result.impact == .none)
    }

    @Test("repeated removals and unwatched action preserve absence")
    func repeatedAbsentActions() throws {
        for action in [
            ViewerMovieStateTransition.Action.removeReaction,
            .removeNotInterested,
            .removeFromWatchlist,
            .markUnwatched,
        ] {
            let result = try ViewerMovieStateTestFixtures.reduce(action)

            #expect(result.state == nil)
            #expect(result.impact == .none)
            #expect(!result.metadataChanged)
        }
    }

    @Test("already-unwatched actions preserve existing future or rejection state")
    func alreadyUnwatched() throws {
        let saved = try ViewerMovieStateTestFixtures.state(
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let savedResult = try ViewerMovieStateTestFixtures.reduce(.markUnwatched, current: saved)
        let rejectedResult = try ViewerMovieStateTestFixtures.reduce(.markUnwatched, current: rejected)

        #expect(savedResult.state == saved)
        #expect(savedResult.impact == .none)
        #expect(rejectedResult.state == rejected)
        #expect(rejectedResult.impact == .none)
    }

    @Test("undoing absent meanings preserves the remaining state")
    func absentMeaningUndo() throws {
        let watched = try ViewerMovieStateTestFixtures.state(watchState: .watched)
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let ratingResult = try ViewerMovieStateTestFixtures.reduce(.removeReaction, current: watched)
        let watchlistResult = try ViewerMovieStateTestFixtures.reduce(.removeFromWatchlist, current: rejected)

        #expect(ratingResult.state == watched)
        #expect(ratingResult.impact == .none)
        #expect(watchlistResult.state == rejected)
        #expect(watchlistResult.impact == .none)
    }

    @Test("setting not interested again preserves the original state time")
    func repeatedNotInterested() throws {
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let result = try ViewerMovieStateTestFixtures.reduce(.setNotInterested, current: rejected)

        #expect(result.state == rejected)
        #expect(result.state?.stateChangedAt == ViewerMovieStateTestFixtures.initialDate)
        #expect(result.impact == .none)
    }

    @Test("metadata refresh is independent from semantic state")
    func metadataRefresh() throws {
        let rated = try ViewerMovieStateTestFixtures.state(
            watchState: .watched,
            preference: .reaction(.loveIt)
        )
        let refreshedMetadata = try ViewerMovieStateTestFixtures.metadata(
            title: "La llegada",
            posterPath: "/arrival-es.jpg"
        )

        let result = try ViewerMovieStateTestFixtures.reduce(
            .assignReaction(.loveIt),
            current: rated,
            metadata: refreshedMetadata
        )

        #expect(result.state?.displayMetadata == refreshedMetadata)
        #expect(result.state?.stateChangedAt == ViewerMovieStateTestFixtures.initialDate)
        #expect(result.impact == .none)
        #expect(result.metadataChanged)
    }

    @Test("taste impact wins over eligibility and Watchlist effects")
    func tastePrecedence() throws {
        let saved = try ViewerMovieStateTestFixtures.state(
            watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
        )

        let result = try ViewerMovieStateTestFixtures.reduce(
            .assignReaction(.itWasOkay),
            current: saved
        )

        #expect(result.state?.watchState == .watched)
        #expect(result.state?.watchlistIntent == nil)
        #expect(result.impact == .tasteChanged)
    }

    @Test("eligibility impact wins over Watchlist-only effects")
    func eligibilityPrecedence() throws {
        let rejected = try ViewerMovieStateTestFixtures.state(preference: .notInterested)

        let result = try ViewerMovieStateTestFixtures.reduce(.saveToWatchlist, current: rejected)

        #expect(result.state?.preference == nil)
        #expect(result.state?.watchlistIntent != nil)
        #expect(result.impact == .eligibilityChanged)
    }
}
