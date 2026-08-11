@testable import PickOne
import Testing

@Suite("P1 synthetic scoring fixture tests")
struct P1ScoringFixtureTests {
    @Test("Fixture A reproduces C1 greater than C2 greater than C5 greater than C3 greater than C4")
    func fixtureA() {
        let ranked = rank(
            P1ScoringTestFixtures.fixtureACandidates,
            profile: P1ScoringTestFixtures.fixtureAProfile
        )

        #expect(ranked.map(\.name) == ["C1", "C2", "C5", "C3", "C4"])
    }

    @Test("Fixture B keeps sparse known fit first and unrelated quality credible")
    func fixtureB() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(1, .loveIt, [.thriller, .drama], 2015),
            evidence(2, .didNotLikeIt, [.comedy], 2012),
        ])
        let candidates = [
            candidate("C1", 101, [.thriller, .drama], 2016, 8.1, 12000),
            candidate("C2", 102, [.adventure, .drama], 2018, 8.7, 20000),
            candidate("C3", 103, [.scienceFiction], 2020, 8.7, 20000),
            candidate("C4", 104, [.comedy], 2014, 8.1, 12000),
            candidate("C5", 105, [.crime, .thriller], 2012, 7.0, 2000),
        ]
        let ranked = rank(candidates, profile: profile)

        #expect(ranked.first?.name == "C1")
        #expect(try score(named: "C2", in: ranked).isCredible)
        #expect(try score(named: "C3", in: ranked).isCredible)
        #expect(try score(named: "C4", in: ranked).isCredible)
        #expect(P1Scoring.affinity(for: .comedy, in: profile) > -1)
    }

    @Test("Fixture C keeps Science Fiction positive after one negative observation")
    func fixtureC() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(1, .didNotLikeIt, [.scienceFiction, .horror], 2011),
            evidence(2, .loveIt, [.scienceFiction, .drama], 2014),
            evidence(3, .loveIt, [.scienceFiction, .adventure], 2017),
            evidence(4, .likeIt, [.drama], 2019),
        ])
        let candidates = [
            candidate("C1", 101, [.scienceFiction, .drama], 2016, 8.2, 15000),
            candidate("C2", 102, [.scienceFiction, .adventure], 2018, 8.2, 15000),
            candidate("C3", 103, [.horror], 2017, 8.8, 20000),
            candidate("C4", 104, [.drama], 2015, 8.2, 15000),
        ]
        let ranked = rank(candidates, profile: profile)

        #expect(P1Scoring.affinity(for: .scienceFiction, in: profile) > 0)
        #expect(try score(named: "C1", in: ranked).rankScore > score(named: "C3", in: ranked).rankScore)
        #expect(try score(named: "C2", in: ranked).rankScore > score(named: "C3", in: ranked).rankScore)
    }

    @Test("Fixture F lets the two-point intent bonus change only a close result")
    func fixtureF() {
        let profile = P1TasteProfile(evidence: [
            evidence(1, .loveIt, [.thriller, .drama], 2015),
            evidence(2, .likeIt, [.mystery], 2018),
        ])
        let closeLeader = candidate(
            "C1",
            101,
            [.thriller, .drama],
            2018,
            8.01,
            10000
        )
        let savedClose = candidate(
            "C2",
            102,
            [.thriller, .drama],
            2018,
            7.99,
            10000,
            saved: true
        )
        let savedWeak = candidate(
            "C3",
            103,
            [.comedy],
            1984,
            6.0,
            100,
            saved: true
        )

        let first = P1Scoring.score(closeLeader.input, profile: profile)
        let second = P1Scoring.score(savedClose.input, profile: profile)
        let weak = P1Scoring.score(savedWeak.input, profile: profile)

        #expect(first.baseScore > second.baseScore)
        #expect(second.rankScore > first.rankScore)
        #expect(first.rankScore > weak.rankScore)
    }

    @Test("Fixture G does not make a recent low-vote high-fit candidate impossible")
    func fixtureG() {
        let profile = P1TasteProfile(evidence: [
            evidence(1, .loveIt, [.scienceFiction, .drama], 2017),
            evidence(2, .loveIt, [.scienceFiction, .adventure], 2019),
        ])
        let recent = candidate(
            "recent",
            101,
            [.scienceFiction, .drama, .adventure],
            2024,
            8.5,
            2
        )
        let established = candidate(
            "established",
            102,
            [.scienceFiction, .drama],
            2018,
            8.5,
            20000
        )

        let recentScore = P1Scoring.score(recent.input, profile: profile)
        let establishedScore = P1Scoring.score(established.input, profile: profile)

        #expect(recentScore.qualityComponent >= 0.65)
        #expect(recentScore.isCredible)
        #expect(recentScore.rankScore > 50)
        #expect(establishedScore.qualityComponent > recentScore.qualityComponent)
    }

    @Test("Fixture J keeps personalized Horror and Mystery above unrelated acclaimed quality")
    func fixtureJ() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(1, .loveIt, [.horror, .mystery], 2017),
            evidence(2, .loveIt, [.horror, .thriller], 2019),
            evidence(3, .likeIt, [.mystery], 2015),
        ])
        let candidates = [
            candidate("C1", 101, [.horror, .mystery], 2018, 7.6, 5000),
            candidate("C2", 102, [.action, .adventure], 2018, 8.8, 20000),
            candidate("C3", 103, [.horror], 2016, 7.8, 10000),
        ]
        let ranked = rank(candidates, profile: profile)

        #expect(try score(named: "C1", in: ranked).rankScore > score(named: "C2", in: ranked).rankScore)
        #expect(try score(named: "C3", in: ranked).rankScore > score(named: "C2", in: ranked).rankScore)
    }

    @Test("Fixture K makes okay watched evidence with zero directional affinity")
    func fixtureK() {
        let profile = P1TasteProfile(evidence: [
            evidence(1, .itWasOkay, [.fantasy, .adventure], 2012),
        ])

        #expect(profile.evidence[0].reaction.meansWatchedInCalibration)
        #expect(profile.directionalCount == 0)
        #expect(P1Scoring.affinity(for: .fantasy, in: profile) == 0)
        #expect(P1Scoring.affinity(for: .adventure, in: profile) == 0)
    }

    private func rank(
        _ candidates: [P1NamedCandidate],
        profile: P1TasteProfile
    ) -> [(name: String, score: P1Score)] {
        candidates
            .map { ($0.name, P1Scoring.score($0.input, profile: profile)) }
            .sorted { $0.score.rankScore > $1.score.rankScore }
    }

    private func score(
        named name: String,
        in scores: [(name: String, score: P1Score)]
    ) throws -> P1Score {
        try #require(scores.first(where: { $0.name == name })).score
    }

    private func evidence(
        _ movieID: Int,
        _ reaction: CalibrationReaction,
        _ genres: Set<DecisionGenre>,
        _ releaseYear: Int?
    ) -> TasteReactionEvidence {
        P1ScoringTestFixtures.evidence(movieID, reaction, genres, releaseYear)
    }

    private func candidate(
        _ name: String,
        _ movieID: Int,
        _ genres: Set<DecisionGenre>,
        _ releaseYear: Int?,
        _ voteAverage: Double?,
        _ voteCount: Int?,
        saved: Bool = false
    ) -> P1NamedCandidate {
        P1ScoringTestFixtures.candidate(
            name,
            movieID,
            genres,
            releaseYear,
            voteAverage,
            voteCount,
            saved: saved
        )
    }
}

private extension DecisionGenre {
    static let action = P1FixtureGenre.action
    static let adventure = P1FixtureGenre.adventure
    static let comedy = P1FixtureGenre.comedy
    static let crime = P1FixtureGenre.crime
    static let drama = P1FixtureGenre.drama
    static let fantasy = P1FixtureGenre.fantasy
    static let horror = P1FixtureGenre.horror
    static let mystery = P1FixtureGenre.mystery
    static let scienceFiction = P1FixtureGenre.scienceFiction
    static let thriller = P1FixtureGenre.thriller
}
