import Foundation
@testable import PickOne
import Testing

struct PickOneProvenanceTests {
    @Test func confirmationIsIndependentFromReactionAndUnwatchedRemovesProvenance() throws {
        let metadata = try MovieFeedbackMetadata(title: "Movie", releaseYear: 2020, posterPath: nil)
        let provenance = PickOneViewingProvenance(confirmationOperationID: UUID(), confirmedAt: Date())
        let confirmed = try ViewerMovieStateReducer.reduce(
            current: nil, transition: .init(movieID: 1, action: .confirmPick(provenance)), metadata: metadata,
            at: provenance.confirmedAt
        )
        #expect(confirmed.state?.watchState == .watched)
        #expect(confirmed.state?.pickOneProvenance == provenance)
        #expect(confirmed.state?.reaction == nil)
        let repeated = try ViewerMovieStateReducer.reduce(
            current: confirmed.state, transition: .init(movieID: 1, action: .confirmPick(provenance)),
            metadata: metadata, at: Date()
        )
        #expect(repeated.state == confirmed.state)
        let unwatched = try ViewerMovieStateReducer.reduce(
            current: confirmed.state, transition: .init(movieID: 1, action: .markUnwatched), metadata: metadata,
            at: Date()
        )
        #expect(unwatched.state == nil)
    }
}
