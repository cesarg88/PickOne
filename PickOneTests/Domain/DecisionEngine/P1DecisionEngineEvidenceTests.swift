@testable import PickOne
import Testing

@Suite("P1 Decision Engine explanation evidence tests")
struct P1DecisionEngineEvidenceTests {
    private let engine = P1DecisionEngine()

    @Test("saved intent plus genuine taste match takes precedence over anchor evidence")
    func watchlistPrecedence() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(100, title: "Arrival", .loveIt, [.scienceFiction, .drama], 2016),
        ])
        let selection = try engine.select(from: input(
            profile: profile,
            candidates: [candidate(1, [.scienceFiction, .drama], year: 2018)],
            savedUnwatchedMovieIDs: [1]
        ))
        let recommendation = try #require(selection.recommendations.first)

        guard case let .watchlistIntent(match) = recommendation.evidence.primary else {
            Issue.record("Expected saved Watchlist intent to be the primary evidence")
            return
        }
        guard case let .positiveAnchor(anchor) = match else {
            Issue.record("Expected the saved intent to retain its genuine anchor match")
            return
        }
        #expect(anchor.movieTitle == "Arrival")
        #expect(anchor.reaction == .loved)
        #expect(anchor.sharedGenres.map(\.id) == [18, 878])
        #expect(anchor.eraMatch != nil)
    }

    @Test("a named positive anchor takes precedence over learned genre affinity")
    func anchorPrecedence() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(100, title: "Arrival", .likeIt, [.scienceFiction, .drama], 2016),
        ])
        let selection = try engine.select(from: input(
            profile: profile,
            candidates: [candidate(1, [.scienceFiction, .drama], year: 2019)]
        ))
        let primary = try #require(selection.recommendations.first?.evidence.primary)

        guard case let .positiveAnchor(anchor) = primary else {
            Issue.record("Expected named anchor evidence")
            return
        }
        #expect(anchor.movieTitle == "Arrival")
        #expect(anchor.reaction == .liked)
    }

    @Test("positive genre affinity is used when no named anchor can be claimed")
    func genreAffinityFallback() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(100, title: nil, .loveIt, [.drama], 2016),
        ])
        let selection = try engine.select(from: input(
            profile: profile,
            candidates: [candidate(1, [.drama], year: 2019)]
        ))
        let primary = try #require(selection.recommendations.first?.evidence.primary)

        guard case let .positiveGenreAffinity(affinity) = primary else {
            Issue.record("Expected positive genre affinity evidence")
            return
        }
        #expect(affinity.genres.map(\.id) == [18])
    }

    @Test("general quality is an honest fallback only while the profile is sparse")
    func sparseQualityFallback() throws {
        let selection = try engine.select(from: input(
            candidates: [candidate(1, [.drama], year: 2019)]
        ))

        #expect(selection.recommendations.first?.evidence.primary == .sparseQuality)
    }

    @Test("saving without a taste match does not invent a personalized Watchlist reason")
    func savedWithoutTasteMatch() throws {
        let selection = try engine.select(from: input(
            candidates: [candidate(1, [.drama], year: 2019)],
            savedUnwatchedMovieIDs: [1]
        ))

        #expect(selection.recommendations.first?.evidence.primary == .sparseQuality)
    }

    @Test("saved intent may use supported positive era affinity as its genuine match")
    func watchlistEraMatch() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(100, title: nil, .loveIt, [.thriller], 2016),
        ])
        let selection = try engine.select(from: input(
            profile: profile,
            candidates: [candidate(1, [.comedy], year: 2018)],
            savedUnwatchedMovieIDs: [1]
        ))
        let primary = try #require(selection.recommendations.first?.evidence.primary)

        guard case let .watchlistIntent(match) = primary else {
            Issue.record("Expected Watchlist intent backed by era affinity")
            return
        }
        guard case let .positiveAffinity(affinity) = match else {
            Issue.record("Expected positive affinity support")
            return
        }
        #expect(affinity.genres.isEmpty)
        #expect(affinity.era == DecisionDecade(year: 2018))
    }

    @Test("a credible normal-profile candidate without supported fit evidence is omitted")
    func unsupportedReasonIsOmitted() throws {
        let profile = P1TasteProfile(evidence: [
            evidence(100, title: nil, .loveIt, [.drama], 1984),
            evidence(101, title: nil, .likeIt, [.thriller], 1994),
            evidence(102, title: nil, .didNotLikeIt, [.comedy], 2004),
        ])
        let selection = try engine.select(from: input(
            profile: profile,
            candidates: [candidate(1, [], year: nil)]
        ))
        let rawScore = P1Scoring.score(
            P1CandidateScoreInput(
                movieID: 1,
                genres: [],
                releaseYear: nil,
                voteAverage: 8.5,
                voteCount: 20000,
                isSavedAndUnwatched: false
            ),
            profile: profile
        )

        #expect(rawScore.isCredible)
        #expect(selection.recommendations.isEmpty)
    }

    @Test("diversity is secondary context and never replaces the primary reason")
    func diversityIsSecondary() throws {
        let candidates = try [
            candidate(1, [.scienceFiction, .drama], rating: 8.5),
            candidate(2, [.scienceFiction, .drama], rating: 8.4),
            candidate(3, [.scienceFiction, .adventure], rating: 8.3),
        ]
        let selection = engine.select(from: input(candidates: candidates))
        let stretch = try #require(selection.recommendations.first(where: { $0.role == .stretchChoice }))
        #expect(stretch.evidence.diversity == .diverseDirection)
        #expect(stretch.evidence.primary == .sparseQuality)
    }

    @Test("identical genre roles do not claim a different direction")
    func noUnsupportedDiversityClaim() throws {
        let candidates = try [
            candidate(1, [.drama], rating: 8.5),
            candidate(2, [.drama], rating: 8.4),
        ]
        let selection = engine.select(from: input(candidates: candidates))
        let stretch = try #require(selection.recommendations.first(where: { $0.role == .stretchChoice }))

        #expect(stretch.evidence.diversity == nil)
        #expect(stretch.evidence.primary == .sparseQuality)
    }

    private func input(
        profile: P1TasteProfile = P1TasteProfile(evidence: []),
        candidates: [DecisionCandidate],
        savedUnwatchedMovieIDs: Set<Int> = []
    ) -> DecisionEngineInput {
        DecisionEngineInput(
            profile: profile,
            candidates: candidates,
            watchlistWatchedMovieIDs: [],
            savedUnwatchedMovieIDs: savedUnwatchedMovieIDs,
            currentCycleShownMovieIDs: []
        )
    }

    private func candidate(
        _ movieID: Int,
        _ genres: Set<DecisionGenre>,
        year: Int? = 2020,
        rating: Double = 8.5
    ) throws -> DecisionCandidate {
        try #require(DecisionCandidate(
            movieID: movieID,
            genres: genres,
            releaseYear: year,
            voteAverage: rating,
            voteCount: 20000,
            availability: .eligible
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
}

private extension DecisionGenre {
    static let adventure = DecisionGenre(id: 12, name: "Adventure")
    static let comedy = DecisionGenre(id: 35, name: "Comedy")
    static let drama = DecisionGenre(id: 18, name: "Drama")
    static let scienceFiction = DecisionGenre(id: 878, name: "Science Fiction")
    static let thriller = DecisionGenre(id: 53, name: "Thriller")
}
