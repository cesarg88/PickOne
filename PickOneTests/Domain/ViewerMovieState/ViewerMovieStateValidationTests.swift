import Foundation
@testable import PickOne
import Testing

@Suite("Viewer Movie State validation tests")
struct ViewerMovieStateValidationTests {
    @Test("metadata requires a displayable title")
    func metadataRequiresTitle() {
        #expect(throws: ViewerMovieStateValidationError.emptyTitle) {
            try MovieFeedbackMetadata(title: "  \n", releaseYear: nil, posterPath: nil)
        }
    }

    @Test("movie identity must be a positive TMDB ID")
    func positiveMovieIdentity() throws {
        #expect(throws: ViewerMovieStateValidationError.invalidMovieID) {
            try ViewerMovieState(
                movieID: 0,
                displayMetadata: ViewerMovieStateTestFixtures.metadata(),
                watchState: .watched,
                preference: nil,
                watchlistIntent: nil,
                stateChangedAt: ViewerMovieStateTestFixtures.initialDate
            )
        }
    }

    @Test("a reaction requires watched state")
    func reactionRequiresWatched() throws {
        #expect(throws: ViewerMovieStateValidationError.reactionRequiresWatched) {
            try ViewerMovieStateTestFixtures.state(
                preference: .reaction(.loveIt)
            )
        }
    }

    @Test("not interested requires unwatched state")
    func notInterestedRequiresUnwatched() throws {
        #expect(throws: ViewerMovieStateValidationError.notInterestedRequiresUnwatched) {
            try ViewerMovieStateTestFixtures.state(
                watchState: .watched,
                preference: .notInterested
            )
        }
    }

    @Test("Watchlist intent requires unwatched state")
    func watchlistRequiresUnwatched() throws {
        #expect(throws: ViewerMovieStateValidationError.watchlistRequiresUnwatched) {
            try ViewerMovieStateTestFixtures.state(
                watchState: .watched,
                watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
            )
        }
    }

    @Test("preference and Watchlist intent cannot coexist")
    func preferenceAndWatchlistConflict() throws {
        #expect(throws: ViewerMovieStateValidationError.preferenceConflictsWithWatchlist) {
            try ViewerMovieStateTestFixtures.state(
                preference: .notInterested,
                watchlistIntent: WatchlistIntent(addedAt: ViewerMovieStateTestFixtures.initialDate)
            )
        }
    }

    @Test("an empty unwatched record is rejected as a tombstone")
    func emptyTombstone() throws {
        #expect(throws: ViewerMovieStateValidationError.emptyUnwatchedState) {
            try ViewerMovieStateTestFixtures.state()
        }
    }

    @Test("watched without a reaction remains meaningful")
    func watchedOnlyState() throws {
        let state = try ViewerMovieStateTestFixtures.state(watchState: .watched)

        #expect(state.watchState == .watched)
        #expect(state.preference == nil)
        #expect(state.watchlistIntent == nil)
    }

    @Test("snapshot rejects duplicate movie identities")
    func duplicateSnapshotIdentity() throws {
        let first = try ViewerMovieStateTestFixtures.state(watchState: .watched)
        let second = try ViewerMovieStateTestFixtures.state(
            title: "La llegada",
            watchState: .watched
        )

        #expect(throws: ViewerMovieStateSnapshotValidationError.duplicateMovieID(first.movieID)) {
            try ViewerMovieStateSnapshot(
                id: ViewerStateSnapshotID(rawValue: UUID()),
                states: [first, second]
            )
        }
    }
}
