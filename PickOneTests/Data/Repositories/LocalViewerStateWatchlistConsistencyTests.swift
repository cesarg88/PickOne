import Foundation
@testable import PickOne
import Testing

@Suite("Local Viewer State Watchlist consistency")
struct ViewerStateWatchlistConsistencyTests {
    @Test("removing Watchlist intent from watched-only state is a persisted no-op")
    func removingWatchlistIntentFromWatchedOnlyStateIsNoOp() async throws {
        let snapshotID = try LocalViewerStateTestFixtures.uuid(
            LocalViewerStateTestFixtures.firstID
        )
        let watched = try ViewerMovieState(
            movieID: 500,
            displayMetadata: LocalViewerStateTestFixtures.metadata(),
            watchState: .watched,
            preference: nil,
            watchlistIntent: nil,
            stateChangedAt: LocalViewerStateTestFixtures.date
        )
        let base = LocalViewerStateTestFixtures.emptyEnvelope(id: snapshotID)
        let envelope = LocalViewerStateEnvelopeMapper().replacingStates(
            in: base,
            snapshotID: snapshotID,
            states: [watched]
        )
        let original = try LocalViewerStateTestFixtures.encoded(envelope)
        let files = InMemoryLocalViewerStateFileStore(activeData: original)
        let stateRepository = LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource()
        )
        let watchlist = LocalViewerStateWatchlistAdapter(repository: stateRepository)
        let movie = MovieSummary(
            id: watched.movieID,
            title: watched.displayMetadata.title,
            posterPath: watched.displayMetadata.posterPath,
            releaseYear: watched.displayMetadata.releaseYear,
            rating: 0
        )

        let outcome = try await watchlist.setMembership(
            movie: movie,
            isInWatchlist: false
        )

        #expect(outcome == WatchlistMutationOutcome(status: .watched, didChange: false))
        #expect(try await stateRepository.state(movieID: watched.movieID) == watched)
        #expect(try await stateRepository.snapshot().id.rawValue == snapshotID)
        #expect(files.activeData == original)
        #expect(files.activeReplacementCount == 0)
    }
}
