struct DecisionGenre: Hashable, Sendable {
    let id: Int
}

struct DecisionDecade: Hashable, Sendable {
    let startingYear: Int

    init(year: Int) {
        startingYear = year - year % 10
    }

    init?(releaseYear: Int?) {
        guard let releaseYear, releaseYear > 0 else {
            return nil
        }
        self.init(year: releaseYear)
    }
}

struct TasteReactionEvidence: Equatable, Sendable {
    let movieID: Int
    let reaction: CalibrationReaction
    let genres: Set<DecisionGenre>
    let releaseYear: Int?
}

struct P1TasteProfile: Equatable, Sendable {
    let evidence: [TasteReactionEvidence]

    var directionalCount: Int {
        evidence.count(where: { $0.reaction.isDirectionalEvidence })
    }
}

struct P1CandidateScoreInput: Equatable, Sendable {
    let movieID: Int
    let genres: Set<DecisionGenre>
    let releaseYear: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let isSavedAndUnwatched: Bool
}

struct P1GenreComponents: Equatable, Sendable {
    let normalizedMeanAffinity: Double
    let positiveCoverage: Double
    let component: Double
}

struct P1ComponentWeights: Equatable, Sendable {
    let genre: Double
    let era: Double
    let similarity: Double
    let quality: Double

    var total: Double {
        genre + era + similarity + quality
    }
}

struct P1Quality: Equatable, Sendable {
    let ratingComponent: Double
    let voteEvidence: Double
    let component: Double
}

struct P1Score: Equatable, Sendable {
    let normalizedMeanGenreAffinity: Double
    let positiveGenreCoverage: Double
    let genreComponent: Double
    let eraComponent: Double
    let profileConfidence: Double
    let weights: P1ComponentWeights
    let similarityComponent: Double
    let ratingComponent: Double
    let voteEvidence: Double
    let qualityComponent: Double
    let baseScore: Double
    let watchlistIntentBonus: Double
    let rankScore: Double
    let isCredible: Bool
}
