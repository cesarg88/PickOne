import Foundation
@testable import PickOne
import Testing

@Suite("Decision repair composer")
struct DecisionRepairComposerTests {
    @Test("repair changes require a valid movie identity")
    func repairChangeValidatesIdentity() {
        #expect(DecisionEligibilityChange(movieID: 0, cause: .watchlist) == nil)
        #expect(DecisionEligibilityChange(movieID: 10, cause: .availability) != nil)
    }

    @Test("retains valid members, fills open slots, and restores prefix roles")
    func retainsAndFillsOpenSlots() throws {
        let profile = P1TasteProfile(evidence: [
            TasteReactionEvidence(
                movieID: 900,
                movieTitle: "Anchor",
                reaction: .loveIt,
                genres: [DecisionGenre(id: 1, name: "Drama")],
                releaseYear: 2020
            ),
        ])
        let candidates = try [
            candidate(id: 10, genreID: 1, rating: 8.5),
            candidate(id: 20, genreID: 2, rating: 8.4),
            candidate(id: 30, genreID: 3, rating: 8.3),
            candidate(id: 40, genreID: 4, rating: 8.2),
        ]
        let input = DecisionEngineInput(
            profile: profile,
            candidates: candidates,
            recommendationExcludedMovieIDs: [],
            savedUnwatchedMovieIDs: [],
            currentCycleShownMovieIDs: [20, 30]
        )

        let selection = P1DecisionRepairComposer().compose(
            input: input,
            mandatoryRetainedMovieIDs: [20, 30],
            maximumCount: 3
        )

        #expect(Set(selection.recommendations.map(\.candidate.movieID)).isSuperset(of: [20, 30]))
        #expect(selection.recommendations.count == 3)
        #expect(selection.recommendations.map(\.role) == [
            .safeChoice,
            .stretchChoice,
            .discoveryChoice,
        ])
    }

    @Test("never backfills with an ineligible mandatory member")
    func rejectsInvalidMandatoryMember() throws {
        let watched = try candidate(id: 10, genreID: 1, rating: 8.5)
        let replacement = try candidate(id: 20, genreID: 2, rating: 8.4)
        let input = DecisionEngineInput(
            profile: P1TasteProfile(evidence: []),
            candidates: [watched, replacement],
            recommendationExcludedMovieIDs: [10],
            savedUnwatchedMovieIDs: [],
            currentCycleShownMovieIDs: []
        )

        let selection = P1DecisionRepairComposer().compose(
            input: input,
            mandatoryRetainedMovieIDs: [10],
            maximumCount: 3
        )

        #expect(selection.recommendations.map(\.candidate.movieID) == [20])
        #expect(selection.recommendations.map(\.role) == [.safeChoice])
    }

    private func candidate(
        id: Int,
        genreID: Int,
        rating: Double
    ) throws -> DecisionCandidate {
        try #require(DecisionCandidate(
            movieID: id,
            genres: [DecisionGenre(id: genreID, name: "Genre \(genreID)")],
            releaseYear: 2020,
            voteAverage: rating,
            voteCount: 20000,
            availability: .eligible
        ))
    }
}
