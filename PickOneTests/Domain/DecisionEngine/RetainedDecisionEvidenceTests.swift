import Foundation
@testable import PickOne
import Testing

@Suite("Retained Decision evidence")
struct RetainedDecisionEvidenceTests {
    @Test("sparse quality remains valid below one-third current confidence")
    func sparseQualityRemainsValidForSparseCurrentState() throws {
        let source = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let trusted = try trustedState(reactions: [
            101: .loveIt,
            102: .didNotLikeIt,
            103: .itWasOkay,
        ])

        let retained = try #require(
            ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
                source,
                trustedState: trusted
            )
        )

        #expect(retained.decisionSet.recommendations.map(\.display.movieID) == [10])
    }

    @Test("sparse quality is unsafe at one-third current confidence")
    func sparseQualityIsUnsafeForEstablishedCurrentState() throws {
        let source = try CoordinatorTestFixtures.envelope(currentMovieIDs: [10])
        let trusted = try trustedState(reactions: [
            101: .loveIt,
            102: .likeIt,
            103: .didNotLikeIt,
        ])

        let retained = try #require(
            ThreeForTonightSnapshotFactory.safeRetainedSnapshot(
                source,
                trustedState: trusted
            )
        )

        #expect(retained.decisionSet.recommendations.isEmpty)
    }

    private func trustedState(
        reactions: [Int: MovieReaction]
    ) throws -> TrustedDecisionState {
        let states = try reactions.map { movieID, reaction in
            try ViewerMovieState(
                movieID: movieID,
                displayMetadata: MovieFeedbackMetadata(
                    title: "Movie \(movieID)",
                    releaseYear: 2024,
                    posterPath: nil
                ),
                watchState: .watched,
                preference: .reaction(reaction),
                watchlistIntent: nil,
                stateChangedAt: .distantPast
            )
        }
        return try TrustedDecisionState(
            profile: CoordinatorTestFixtures.sparseProfile(),
            viewerMovieState: ViewerMovieStateSnapshot(
                id: ViewerStateSnapshotID(rawValue: UUID()),
                states: states
            )
        )
    }
}
