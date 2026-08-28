@testable import PickOne
import Testing

@Suite("P1 Decision Engine selection tests")
struct P1DecisionEngineSelectionTests {
    private let engine = P1DecisionEngine()

    @Test("Fixture D excludes ineligible and unknown availability before role assignment")
    func fixtureD() throws {
        let candidates = try [
            candidate(1, [.crime, .thriller, .drama], rating: 8.5, availability: .ineligible),
            candidate(2, [.crime, .thriller], rating: 8.4, availability: .unknown),
            candidate(3, [.crime, .drama], rating: 8.3),
            candidate(4, [.thriller, .drama], rating: 8.2),
        ]

        let selection = engine.select(from: input(candidates: candidates))

        #expect(selection.recommendations.map(\.candidate.movieID) == [3, 4])
        #expect(selection.recommendations.map(\.role) == [.safeChoice, .stretchChoice])
    }

    @Test("Fixture E excludes calibration and Watchlist watched movies but keeps saved intent")
    func fixtureE() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(1, title: "Seen anchor", .loveIt, [.drama], 2014),
        ])
        let candidates = try [
            candidate(1, [.drama], year: 2014, rating: 8.5),
            candidate(2, [.drama], year: 2016, rating: 8.4),
            candidate(3, [.drama], year: 2018, rating: 8.3),
        ]

        let selection = engine.select(from: input(
            profile: profile,
            candidates: candidates,
            recommendationExcludedMovieIDs: [2],
            savedUnwatchedMovieIDs: [3]
        ))

        #expect(selection.recommendations.map(\.candidate.movieID) == [3])
        #expect(selection.recommendations.first?.role == .safeChoice)
    }

    @Test("Fixture H produces the accepted diversified C1 C3 C4 role order")
    func fixtureH() throws {
        let candidates = try diversityCandidates()

        let selection = engine.select(from: input(candidates: candidates))

        #expect(selection.recommendations.map(\.candidate.movieID) == [1, 3, 4])
        #expect(selection.recommendations.map(\.role) == [
            .safeChoice,
            .stretchChoice,
            .discoveryChoice,
        ])
    }

    @Test("Fixture I excludes every movie already shown in the current cycle")
    func fixtureI() throws {
        let candidates = try (1 ... 7).map {
            try candidate($0, [.drama], rating: 8.6 - Double($0) / 10)
        }

        let selection = engine.select(from: input(
            candidates: candidates,
            currentCycleShownMovieIDs: [1, 2, 3]
        ))

        #expect(selection.recommendations.map(\.candidate.movieID) == [4, 5, 6])
    }

    @Test("Fixture L returns successful honest empty when every candidate fails a hard gate")
    func fixtureL() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(3, title: "Already seen", .itWasOkay, [.drama], 2014),
        ])
        let candidates = try [
            candidate(1, [.drama], rating: 8.5, availability: .ineligible),
            candidate(2, [.drama], rating: 8.5, availability: .unknown),
            candidate(3, [.drama], rating: 8.5),
            candidate(4, [.drama], rating: 8.5),
        ]

        let selection = engine.select(from: input(
            profile: profile,
            candidates: candidates,
            recommendationExcludedMovieIDs: [4]
        ))

        #expect(selection.recommendations.isEmpty)
    }

    @Test("one and two qualifying candidates produce honest smaller ordered role sets")
    func smallerSets() throws {
        let first = try candidate(1, [.drama], rating: 8.5)
        let second = try candidate(2, [.thriller], rating: 8.4)

        let one = engine.select(from: input(candidates: [first]))
        let two = engine.select(from: input(candidates: [first, second]))

        #expect(one.recommendations.map(\.role) == [.safeChoice])
        #expect(two.recommendations.map(\.role) == [.safeChoice, .stretchChoice])
    }

    @Test("roles are never backfilled with a below-threshold candidate")
    func noBelowThresholdBackfill() throws {
        let credible = try candidate(1, [.drama], rating: 8.5)
        let belowThreshold = try candidate(2, [.drama], rating: 5.0)

        let selection = engine.select(from: input(
            candidates: [credible, belowThreshold]
        ))

        #expect(selection.recommendations.map(\.candidate.movieID) == [1])
        #expect(selection.recommendations.map(\.role) == [.safeChoice])
    }

    @Test("exact ranking ties prefer quality before movie ID")
    func qualityTieBreak() throws {
        let lowerQuality = try candidate(10, [.drama], rating: 7.8)
        let higherQuality = try candidate(20, [.drama], rating: 8.0)
        let profile = P1TasteProfile(evidence: [])
        let lowerScore = P1Scoring.score(
            scoreInput(for: lowerQuality, isSavedAndUnwatched: true),
            profile: profile
        )
        let higherScore = P1Scoring.score(
            scoreInput(for: higherQuality, isSavedAndUnwatched: false),
            profile: profile
        )
        let selection = engine.select(from: input(
            candidates: [lowerQuality, higherQuality],
            savedUnwatchedMovieIDs: [10]
        ))

        #expect(lowerScore.rankScore == higherScore.rankScore)
        #expect(higherScore.qualityComponent > lowerScore.qualityComponent)
        #expect(selection.recommendations.first?.candidate.movieID == 20)
    }

    @Test("exact score and quality ties prefer the lower TMDB movie ID")
    func movieIDTieBreak() throws {
        let candidates = try [
            candidate(20, [.drama], rating: 8.0),
            candidate(10, [.drama], rating: 8.0),
        ]

        let selection = engine.select(from: input(candidates: candidates))

        #expect(selection.recommendations.map(\.candidate.movieID) == [10, 20])
    }

    @Test("malformed movie identity is rejected at the DecisionCandidate boundary")
    func invalidIdentity() {
        let invalid = DecisionCandidate(
            movieID: 0,
            genres: [.drama],
            releaseYear: 2020,
            voteAverage: 8.0,
            voteCount: 1000,
            availability: .eligible
        )

        #expect(invalid == nil)
    }

    @Test("identical complete snapshots produce exactly equivalent ordered outcomes")
    func deterministicSelection() throws {
        let input = try input(candidates: diversityCandidates())

        #expect(engine.select(from: input) == engine.select(from: input))
    }

    private func diversityCandidates() throws -> [DecisionCandidate] {
        try [
            candidate(1, [.scienceFiction, .drama], rating: 8.5),
            candidate(2, [.scienceFiction, .drama], rating: 8.4),
            candidate(3, [.scienceFiction, .adventure], rating: 8.3),
            candidate(4, [.crime, .drama], rating: 8.2),
            candidate(5, [.mystery, .drama], rating: 8.1),
        ]
    }

    private func input(
        profile: P1TasteProfile = P1TasteProfile(evidence: []),
        candidates: [DecisionCandidate],
        recommendationExcludedMovieIDs: Set<Int> = [],
        savedUnwatchedMovieIDs: Set<Int> = [],
        currentCycleShownMovieIDs: Set<Int> = []
    ) -> DecisionEngineInput {
        DecisionEngineInput(
            profile: profile,
            candidates: candidates,
            recommendationExcludedMovieIDs: recommendationExcludedMovieIDs,
            savedUnwatchedMovieIDs: savedUnwatchedMovieIDs,
            currentCycleShownMovieIDs: currentCycleShownMovieIDs
        )
    }

    private func candidate(
        _ movieID: Int,
        _ genres: Set<DecisionGenre>,
        year: Int? = 2020,
        rating: Double,
        availability: DecisionAvailability = .eligible
    ) throws -> DecisionCandidate {
        try #require(DecisionCandidate(
            movieID: movieID,
            genres: genres,
            releaseYear: year,
            voteAverage: rating,
            voteCount: 20000,
            availability: availability
        ))
    }

    private func evidence(
        _ movieID: Int,
        title: String?,
        _ reaction: CalibrationReaction,
        _ genres: Set<DecisionGenre>,
        _ releaseYear: Int?
    ) -> TasteReactionEvidence {
        TasteReactionEvidence(
            movieID: movieID,
            movieTitle: title,
            reaction: reaction,
            genres: genres,
            releaseYear: releaseYear
        )
    }

    private func scoreInput(
        for candidate: DecisionCandidate,
        isSavedAndUnwatched: Bool
    ) -> P1CandidateScoreInput {
        P1CandidateScoreInput(
            movieID: candidate.movieID,
            genres: candidate.genres,
            releaseYear: candidate.releaseYear,
            voteAverage: candidate.voteAverage,
            voteCount: candidate.voteCount,
            isSavedAndUnwatched: isSavedAndUnwatched
        )
    }
}

private extension DecisionGenre {
    static let adventure = DecisionGenre(id: 12, name: "Adventure")
    static let crime = DecisionGenre(id: 80, name: "Crime")
    static let drama = DecisionGenre(id: 18, name: "Drama")
    static let mystery = DecisionGenre(id: 9648, name: "Mystery")
    static let scienceFiction = DecisionGenre(id: 878, name: "Science Fiction")
    static let thriller = DecisionGenre(id: 53, name: "Thriller")
}
