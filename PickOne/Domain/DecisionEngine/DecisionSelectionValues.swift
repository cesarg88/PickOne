enum DecisionAvailability: Equatable, Sendable {
    case eligible
    case ineligible
    case unknown
}

struct DecisionCandidate: Equatable, Sendable {
    let movieID: Int
    let genres: Set<DecisionGenre>
    let releaseYear: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let availability: DecisionAvailability

    init?(
        movieID: Int,
        genres: Set<DecisionGenre>,
        releaseYear: Int?,
        voteAverage: Double?,
        voteCount: Int?,
        availability: DecisionAvailability
    ) {
        guard movieID > 0 else {
            return nil
        }

        self.movieID = movieID
        self.genres = genres
        self.releaseYear = releaseYear
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.availability = availability
    }
}

struct DecisionEngineInput: Equatable, Sendable {
    let profile: P1TasteProfile
    let candidates: [DecisionCandidate]
    let watchlistWatchedMovieIDs: Set<Int>
    let savedUnwatchedMovieIDs: Set<Int>
    let currentCycleShownMovieIDs: Set<Int>
}

enum DecisionRole: Equatable, Sendable {
    case safeChoice
    case stretchChoice
    case discoveryChoice
}

enum PositiveAnchorReaction: Equatable, Sendable {
    case loved
    case liked
}

enum RecommendationEraMatch: Equatable, Sendable {
    case sameDecade(DecisionDecade)
    case adjacentDecade(candidate: DecisionDecade, anchor: DecisionDecade)
}

struct PositiveAnchorEvidence: Equatable, Sendable {
    let movieID: Int
    let movieTitle: String
    let reaction: PositiveAnchorReaction
    let sharedGenres: [DecisionGenre]
    let eraMatch: RecommendationEraMatch?
}

struct PositiveAffinityEvidence: Equatable, Sendable {
    let genres: [DecisionGenre]
    let era: DecisionDecade?
}

enum RecommendationTasteEvidence: Equatable, Sendable {
    case positiveAnchor(PositiveAnchorEvidence)
    case positiveAffinity(PositiveAffinityEvidence)
}

enum RecommendationPrimaryEvidence: Equatable, Sendable {
    case watchlistIntent(match: RecommendationTasteEvidence)
    case positiveAnchor(PositiveAnchorEvidence)
    case positiveGenreAffinity(PositiveAffinityEvidence)
    case sparseQuality
}

struct RecommendationDiversityEvidence: Equatable, Sendable {
    let supportedBy: RecommendationPrimaryEvidence
}

struct RecommendationEvidence: Equatable, Sendable {
    let primary: RecommendationPrimaryEvidence
    let diversity: RecommendationDiversityEvidence?
}

struct DecisionRecommendation: Equatable, Sendable {
    let candidate: DecisionCandidate
    let role: DecisionRole
    let evidence: RecommendationEvidence
}

struct DecisionSelection: Equatable, Sendable {
    let recommendations: [DecisionRecommendation]
}

protocol DecisionSelecting: Sendable {
    func select(from input: DecisionEngineInput) -> DecisionSelection
}
