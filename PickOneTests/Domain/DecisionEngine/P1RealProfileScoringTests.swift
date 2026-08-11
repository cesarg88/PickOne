@testable import PickOne
import Testing

@Suite("P1 frozen real-profile raw scoring tests")
struct P1RealProfileScoringTests {
    @Test("original onboarding snapshot reproduces the accepted raw top five")
    func originalProfile() {
        let ranked = rank(
            P1ScoringTestFixtures.realCandidates,
            profile: P1ScoringTestFixtures.originalProfile
        )
        let expected: [(String, Double)] = [
            ("The Martian", 65.25),
            ("The Grand Budapest Hotel", 65.23),
            ("Gone Girl", 64.55),
            ("Hereditary", 63.27),
            ("Whiplash", 63.27),
        ]

        #expect(Array(ranked.prefix(5).map(\.name)) == expected.map(\.0))
        for (name, expectedScore) in expected {
            #expect(abs(score(named: name, in: ranked) - expectedScore) < 0.005)
        }
    }

    @Test("augmented snapshot reproduces the accepted eligible raw ranking")
    func augmentedProfile() {
        let candidates = P1ScoringTestFixtures.realCandidates.filter {
            !P1ScoringTestFixtures.augmentedWatchedCandidateIDs.contains(
                $0.input.movieID
            )
        }
        let ranked = rank(
            candidates,
            profile: P1ScoringTestFixtures.augmentedProfile
        )
        let expectedTopTen: [(String, Double)] = [
            ("Us", 67.56),
            ("Nope", 65.72),
            ("Anatomy of a Fall", 65.61),
            ("Arrival", 62.89),
            ("Whiplash", 62.64),
            ("The Prestige", 62.26),
            ("Blade Runner 2049", 61.62),
            ("Mad Max: Fury Road", 60.78),
            ("Prisoners", 60.56),
            ("Knives Out", 59.20),
        ]

        #expect(Array(ranked.prefix(10).map(\.name)) == expectedTopTen.map(\.0))
        for (name, expectedScore) in expectedTopTen {
            #expect(abs(score(named: name, in: ranked) - expectedScore) < 0.005)
        }
        #expect(ranked[15].name == "Oppenheimer")
        #expect(abs(ranked[15].rankScore - 48.45) < 0.005)
        #expect(ranked[16].name == "The Godfather")
        #expect(abs(ranked[16].rankScore - 48.10) < 0.005)
    }

    @Test("augmented Us Watchlist intent adds exactly two raw points")
    func augmentedWatchlistIntent() throws {
        let usCandidate = try #require(
            P1ScoringTestFixtures.realCandidates.first(where: { $0.name == "Us" })
        )
        let savedCandidate = P1CandidateScoreInput(
            movieID: usCandidate.input.movieID,
            genres: usCandidate.input.genres,
            releaseYear: usCandidate.input.releaseYear,
            voteAverage: usCandidate.input.voteAverage,
            voteCount: usCandidate.input.voteCount,
            isSavedAndUnwatched: true
        )

        let baseline = P1Scoring.score(
            usCandidate.input,
            profile: P1ScoringTestFixtures.augmentedProfile
        )
        let saved = P1Scoring.score(
            savedCandidate,
            profile: P1ScoringTestFixtures.augmentedProfile
        )

        #expect(saved.baseScore == baseline.baseScore)
        #expect(saved.rankScore == baseline.rankScore + 2)
        #expect(abs(saved.rankScore - 69.56) < 0.005)
    }

    private func rank(
        _ candidates: [P1NamedCandidate],
        profile: P1TasteProfile
    ) -> [(name: String, rankScore: Double)] {
        candidates
            .map {
                (
                    name: $0.name,
                    rankScore: P1Scoring.score($0.input, profile: profile).rankScore
                )
            }
            .sorted { $0.rankScore > $1.rankScore }
    }

    private func score(
        named name: String,
        in scores: [(name: String, rankScore: Double)]
    ) -> Double {
        scores.first(where: { $0.name == name })?.rankScore ?? .nan
    }
}
