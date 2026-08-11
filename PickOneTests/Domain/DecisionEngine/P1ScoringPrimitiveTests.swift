import Foundation
@testable import PickOne
import Testing

@Suite("P1 scoring primitive tests")
struct P1ScoringPrimitiveTests {
    @Test("reaction values preserve directional and neutral semantics")
    func reactionValues() {
        #expect(CalibrationReaction.loveIt.p1Value == 1.00)
        #expect(CalibrationReaction.likeIt.p1Value == 0.50)
        #expect(CalibrationReaction.itWasOkay.p1Value == 0.00)
        #expect(CalibrationReaction.didNotLikeIt.p1Value == -0.75)
        #expect(CalibrationReaction.haveNotSeenIt.p1Value == nil)
        #expect(CalibrationReaction.doNotKnowIt.p1Value == nil)

        #expect(CalibrationReaction.loveIt.isDirectionalEvidence)
        #expect(CalibrationReaction.likeIt.isDirectionalEvidence)
        #expect(!CalibrationReaction.itWasOkay.isDirectionalEvidence)
        #expect(CalibrationReaction.didNotLikeIt.isDirectionalEvidence)
        #expect(!CalibrationReaction.haveNotSeenIt.isDirectionalEvidence)
        #expect(!CalibrationReaction.doNotKnowIt.isDirectionalEvidence)
    }

    @Test("neutral watched evidence moderates sparse affinity without adding direction")
    func neutralEvidence() {
        let loveOnly = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.drama],
                releaseYear: 2014
            ),
        ])
        let loveAndNeutral = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.drama],
                releaseYear: 2014
            ),
            .init(
                movieID: 2,
                reaction: .itWasOkay,
                genres: [.drama],
                releaseYear: 2018
            ),
        ])

        #expect(P1Scoring.affinity(for: .drama, in: loveOnly) == 1.0 / 3.0)
        #expect(P1Scoring.affinity(for: .drama, in: loveAndNeutral) == 0.25)
        #expect(loveAndNeutral.directionalCount == 1)
        #expect(loveAndNeutral.evidence[1].reaction.meansWatchedInCalibration)
    }

    @Test("sparse evidence shrinks genre and decade affinity toward neutral")
    func evidenceShrinkage() {
        let profile = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.scienceFiction],
                releaseYear: 2014
            ),
        ])

        #expect(P1Scoring.affinity(for: .scienceFiction, in: profile) == 1.0 / 3.0)
        #expect(P1Scoring.affinity(for: DecisionDecade(year: 2014), in: profile) == 1.0 / 3.0)
        #expect(P1Scoring.normalizedAffinity(1.0 / 3.0) == 2.0 / 3.0)
    }

    @Test("unknown genre and decade remain neutral")
    func unknownFeatures() {
        let profile = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.drama],
                releaseYear: 2014
            ),
        ])

        #expect(P1Scoring.affinity(for: .history, in: profile) == 0)
        #expect(P1Scoring.affinity(for: DecisionDecade(year: 1986), in: profile) == 0)
        #expect(P1Scoring.normalizedAffinity(0) == 0.5)
    }

    @Test("adaptive component weights sum to one")
    func adaptiveWeights() {
        for directionalCount in [0, 1, 2, 3, 8, 15, 100] {
            let confidence = P1Scoring.profileConfidence(
                directionalCount: directionalCount
            )
            let weights = P1Scoring.adaptiveWeights(profileConfidence: confidence)

            #expect(abs(weights.total - 1.0) < 1e-12)
        }
    }

    @Test("positive genre coverage counts only signed affinity above the threshold")
    func positiveGenreCoverage() {
        let profile = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.scienceFiction, .drama],
                releaseYear: 2014
            ),
            .init(
                movieID: 2,
                reaction: .didNotLikeIt,
                genres: [.comedy],
                releaseYear: 2004
            ),
        ])

        let components = P1Scoring.genreComponents(
            candidateGenres: [.scienceFiction, .drama, .comedy, .history],
            profile: profile
        )

        #expect(components.positiveCoverage == 0.5)
    }

    @Test("positive-anchor similarity uses strongest supported metadata match")
    func positiveAnchorSimilarity() {
        let profile = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .likeIt,
                genres: [.scienceFiction, .drama],
                releaseYear: 2008
            ),
            .init(
                movieID: 2,
                reaction: .loveIt,
                genres: [.scienceFiction, .drama],
                releaseYear: 2014
            ),
            .init(
                movieID: 3,
                reaction: .didNotLikeIt,
                genres: [.scienceFiction, .drama],
                releaseYear: 2014
            ),
        ])

        let exact = P1Scoring.positiveAnchorSimilarity(
            candidateGenres: [.scienceFiction, .drama],
            releaseYear: 2018,
            profile: profile
        )
        let adjacent = P1Scoring.positiveAnchorSimilarity(
            candidateGenres: [.scienceFiction, .drama],
            releaseYear: 2021,
            profile: profile
        )

        #expect(exact == 1.0)
        #expect(adjacent == 0.9)
    }

    @Test("low vote counts retain the accepted quality-confidence floor")
    func qualityFloor() {
        let lowEvidence = P1Scoring.quality(voteAverage: 8.5, voteCount: 0)
        let established = P1Scoring.quality(voteAverage: 8.5, voteCount: 20000)

        #expect(lowEvidence.ratingComponent == 1.0)
        #expect(lowEvidence.voteEvidence == 0)
        #expect(lowEvidence.component == 0.65)
        #expect(established.component == 1.0)
        #expect(lowEvidence.component > 0)
    }

    @Test("saved and unwatched adds two without mutating Taste Profile")
    func watchlistIntent() {
        let profile = P1TasteProfile(evidence: [
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.thriller],
                releaseYear: 2017
            ),
        ])
        let candidate = P1CandidateScoreInput(
            movieID: 2,
            genres: [.thriller],
            releaseYear: 2019,
            voteAverage: 7.8,
            voteCount: 5000,
            isSavedAndUnwatched: false
        )

        let unsaved = P1Scoring.score(candidate, profile: profile)
        let saved = P1Scoring.score(
            candidate.withSavedAndUnwatched(true),
            profile: profile
        )

        #expect(saved.baseScore == unsaved.baseScore)
        #expect(saved.watchlistIntentBonus == 2.0)
        #expect(saved.rankScore == min(100, unsaved.rankScore + 2.0))
        #expect(profile.directionalCount == 1)
        #expect(profile.evidence.count == 1)
    }

    @Test("normal credibility admits rank score at fifty")
    func normalAdmission() {
        #expect(P1Scoring.isCredible(
            rankScore: 50,
            qualityComponent: 0,
            profileConfidence: 0.5
        ))
        #expect(!P1Scoring.isCredible(
            rankScore: 49.999_999,
            qualityComponent: 1,
            profileConfidence: 0.5
        ))
    }

    @Test("sparse credibility admits quality at point six below one-third confidence")
    func sparseAdmission() {
        #expect(P1Scoring.isCredible(
            rankScore: 49,
            qualityComponent: 0.60,
            profileConfidence: P1Scoring.profileConfidence(directionalCount: 2)
        ))
        #expect(!P1Scoring.isCredible(
            rankScore: 49,
            qualityComponent: 0.599_999,
            profileConfidence: P1Scoring.profileConfidence(directionalCount: 2)
        ))
        #expect(!P1Scoring.isCredible(
            rankScore: 49,
            qualityComponent: 1,
            profileConfidence: P1Scoring.profileConfidence(directionalCount: 3)
        ))
    }

    @Test("missing scoring metadata follows deterministic conservative rules")
    func missingMetadata() {
        let profile = P1TasteProfile(evidence: [])
        let result = P1Scoring.score(
            P1CandidateScoreInput(
                movieID: 1,
                genres: [],
                releaseYear: nil,
                voteAverage: nil,
                voteCount: nil,
                isSavedAndUnwatched: false
            ),
            profile: profile
        )

        #expect(result.normalizedMeanGenreAffinity == 0.5)
        #expect(result.positiveGenreCoverage == 0)
        #expect(result.genreComponent == 0.4)
        #expect(result.eraComponent == 0.5)
        #expect(result.similarityComponent == 0)
        #expect(result.ratingComponent == 0)
        #expect(result.voteEvidence == 0)
        #expect(result.qualityComponent == 0)
    }

    @Test("invalid quality metadata clamps the affected input to zero")
    func invalidQualityMetadata() {
        let invalidRating = P1Scoring.quality(
            voteAverage: .nan,
            voteCount: 20000
        )
        let invalidVotes = P1Scoring.quality(
            voteAverage: 8.5,
            voteCount: -1
        )

        #expect(invalidRating.ratingComponent == 0)
        #expect(invalidRating.component == 0)
        #expect(invalidVotes.voteEvidence == 0)
        #expect(invalidVotes.component == 0.65)
    }

    @Test("raw scores preserve unrounded numeric differences")
    func unroundedScore() {
        let profile = P1TasteProfile(evidence: [])
        let first = P1Scoring.score(
            .init(
                movieID: 1,
                genres: [.drama],
                releaseYear: 2014,
                voteAverage: 8.000_1,
                voteCount: 5000,
                isSavedAndUnwatched: false
            ),
            profile: profile
        )
        let second = P1Scoring.score(
            .init(
                movieID: 2,
                genres: [.drama],
                releaseYear: 2014,
                voteAverage: 8.000_0,
                voteCount: 5000,
                isSavedAndUnwatched: false
            ),
            profile: profile
        )

        #expect(first.rankScore > second.rankScore)
        #expect(first.rankScore.rounded(toPlaces: 2) == second.rankScore.rounded(toPlaces: 2))
    }

    @Test("equivalent evidence ordering produces exactly equivalent raw output")
    func deterministicEvidenceOrdering() {
        let evidence: [TasteReactionEvidence] = [
            .init(
                movieID: 3,
                reaction: .didNotLikeIt,
                genres: [.comedy, .drama],
                releaseYear: 2004
            ),
            .init(
                movieID: 1,
                reaction: .loveIt,
                genres: [.scienceFiction, .drama],
                releaseYear: 2014
            ),
            .init(
                movieID: 2,
                reaction: .likeIt,
                genres: [.thriller, .drama],
                releaseYear: 2018
            ),
        ]
        let candidate = P1CandidateScoreInput(
            movieID: 4,
            genres: [.thriller, .scienceFiction, .drama, .comedy],
            releaseYear: 2019,
            voteAverage: 7.812_345,
            voteCount: 4321,
            isSavedAndUnwatched: false
        )

        let forward = P1Scoring.score(
            candidate,
            profile: P1TasteProfile(evidence: evidence)
        )
        let reversed = P1Scoring.score(
            candidate,
            profile: P1TasteProfile(evidence: Array(evidence.reversed()))
        )

        #expect(forward == reversed)
    }
}

private extension DecisionGenre {
    static let action = DecisionGenre(id: 28)
    static let comedy = DecisionGenre(id: 35)
    static let drama = DecisionGenre(id: 18)
    static let history = DecisionGenre(id: 36)
    static let scienceFiction = DecisionGenre(id: 878)
    static let thriller = DecisionGenre(id: 53)
}

private extension P1CandidateScoreInput {
    func withSavedAndUnwatched(_ value: Bool) -> P1CandidateScoreInput {
        P1CandidateScoreInput(
            movieID: movieID,
            genres: genres,
            releaseYear: releaseYear,
            voteAverage: voteAverage,
            voteCount: voteCount,
            isSavedAndUnwatched: value
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
