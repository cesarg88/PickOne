import Foundation

enum P1Scoring {
    static func affinity(
        for genre: DecisionGenre,
        in profile: P1TasteProfile
    ) -> Double {
        affinity(
            from: profile.evidence.filter { $0.genres.contains(genre) }
        )
    }

    static func affinity(
        for decade: DecisionDecade,
        in profile: P1TasteProfile
    ) -> Double {
        affinity(
            from: profile.evidence.filter {
                DecisionDecade(releaseYear: $0.releaseYear) == decade
            }
        )
    }

    static func normalizedAffinity(_ affinity: Double) -> Double {
        (affinity + 1.0) / 2.0
    }

    static func genreComponents(
        candidateGenres: Set<DecisionGenre>,
        profile: P1TasteProfile
    ) -> P1GenreComponents {
        guard !candidateGenres.isEmpty else {
            return P1GenreComponents(
                normalizedMeanAffinity: 0.50,
                positiveCoverage: 0,
                component: 0.40
            )
        }

        let affinities = candidateGenres
            .sorted { $0.id < $1.id }
            .map { affinity(for: $0, in: profile) }
        let normalizedMeanAffinity = affinities
            .map(normalizedAffinity)
            .reduce(0, +) / Double(affinities.count)
        let positiveCoverage = Double(
            affinities.count(where: { $0 > 0.05 })
        ) / Double(affinities.count)

        return P1GenreComponents(
            normalizedMeanAffinity: normalizedMeanAffinity,
            positiveCoverage: positiveCoverage,
            component: normalizedMeanAffinity * 0.80 + positiveCoverage * 0.20
        )
    }

    static func profileConfidence(directionalCount: Int) -> Double {
        let count = Double(max(0, directionalCount))
        return count / (count + 6.0)
    }

    static func adaptiveWeights(
        profileConfidence: Double
    ) -> P1ComponentWeights {
        let confidence = clamp(profileConfidence, minimum: 0, maximum: 1)
        let quality = 0.35 - 0.20 * confidence
        let personal = 1.0 - quality

        return P1ComponentWeights(
            genre: personal * 0.65,
            era: personal * 0.10,
            similarity: personal * 0.25,
            quality: quality
        )
    }

    static func positiveAnchorSimilarity(
        candidateGenres: Set<DecisionGenre>,
        releaseYear: Int?,
        profile: P1TasteProfile
    ) -> Double {
        profile.evidence.reduce(0) { strongest, anchor in
            guard anchor.reaction.isPositiveP1Anchor else {
                return strongest
            }

            return max(
                strongest,
                positiveAnchorSimilarity(
                    candidateGenres: candidateGenres,
                    releaseYear: releaseYear,
                    anchor: anchor
                )
            )
        }
    }

    static func positiveAnchorSimilarity(
        candidateGenres: Set<DecisionGenre>,
        releaseYear: Int?,
        anchor: TasteReactionEvidence
    ) -> Double {
        guard let anchorStrength = anchor.reaction.p1AnchorStrength else {
            return 0
        }

        let overlap = genreJaccard(candidateGenres, anchor.genres)
        let era = eraSimilarity(releaseYear, anchor.releaseYear)
        let metadataSimilarity = overlap * 0.80 + era * 0.20
        return metadataSimilarity * anchorStrength
    }

    static func quality(
        voteAverage: Double?,
        voteCount: Int?
    ) -> P1Quality {
        let ratingComponent: Double = if let voteAverage, voteAverage.isFinite {
            clamp(
                (voteAverage - 5.0) / 3.5,
                minimum: 0,
                maximum: 1
            )
        } else {
            0
        }

        let voteEvidence: Double = if let voteCount, voteCount >= 0 {
            clamp(
                log1p(Double(voteCount)) / log1p(20000.0),
                minimum: 0,
                maximum: 1
            )
        } else {
            0
        }

        return P1Quality(
            ratingComponent: ratingComponent,
            voteEvidence: voteEvidence,
            component: ratingComponent * (0.65 + 0.35 * voteEvidence)
        )
    }

    static func score(
        _ candidate: P1CandidateScoreInput,
        profile: P1TasteProfile
    ) -> P1Score {
        let genre = genreComponents(
            candidateGenres: candidate.genres,
            profile: profile
        )
        let era = candidate.releaseYear.flatMap(DecisionDecade.init(releaseYear:))
            .map { normalizedAffinity(affinity(for: $0, in: profile)) }
            ?? 0.50
        let confidence = profileConfidence(
            directionalCount: profile.directionalCount
        )
        let weights = adaptiveWeights(profileConfidence: confidence)
        let similarity = positiveAnchorSimilarity(
            candidateGenres: candidate.genres,
            releaseYear: candidate.releaseYear,
            profile: profile
        )
        let quality = quality(
            voteAverage: candidate.voteAverage,
            voteCount: candidate.voteCount
        )
        let baseScore = 100.0 * (
            genre.component * weights.genre
                + era * weights.era
                + similarity * weights.similarity
                + quality.component * weights.quality
        )
        let watchlistIntentBonus = candidate.isSavedAndUnwatched ? 2.0 : 0.0
        let rankScore = min(100.0, baseScore + watchlistIntentBonus)

        return P1Score(
            normalizedMeanGenreAffinity: genre.normalizedMeanAffinity,
            positiveGenreCoverage: genre.positiveCoverage,
            genreComponent: genre.component,
            eraComponent: era,
            profileConfidence: confidence,
            weights: weights,
            similarityComponent: similarity,
            ratingComponent: quality.ratingComponent,
            voteEvidence: quality.voteEvidence,
            qualityComponent: quality.component,
            baseScore: baseScore,
            watchlistIntentBonus: watchlistIntentBonus,
            rankScore: rankScore,
            isCredible: isCredible(
                rankScore: rankScore,
                qualityComponent: quality.component,
                profileConfidence: confidence
            )
        )
    }

    static func isCredible(
        rankScore: Double,
        qualityComponent: Double,
        profileConfidence: Double
    ) -> Bool {
        rankScore >= 50.0
            || (
                profileConfidence < 1.0 / 3.0
                    && qualityComponent >= 0.60
            )
    }

    private static func affinity(
        from evidence: [TasteReactionEvidence]
    ) -> Double {
        let values = evidence
            .sorted { $0.movieID < $1.movieID }
            .compactMap(\.reaction.p1Value)
        guard !values.isEmpty else {
            return 0
        }

        let observationCount = Double(values.count)
        let rawMean = values.reduce(0, +) / observationCount
        let evidenceConfidence = observationCount / (observationCount + 2.0)
        return rawMean * evidenceConfidence
    }

    static func genreJaccard(
        _ first: Set<DecisionGenre>,
        _ second: Set<DecisionGenre>
    ) -> Double {
        let unionCount = first.union(second).count
        guard unionCount > 0 else {
            return 0
        }
        return Double(first.intersection(second).count) / Double(unionCount)
    }

    static func eraSimilarity(
        _ firstYear: Int?,
        _ secondYear: Int?
    ) -> Double {
        guard
            let first = DecisionDecade(releaseYear: firstYear),
            let second = DecisionDecade(releaseYear: secondYear)
        else {
            return 0
        }

        let difference = abs(first.startingYear - second.startingYear)
        switch difference {
            case 0: return 1.0
            case 10: return 0.5
            default: return 0
        }
    }

    private static func clamp(
        _ value: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        min(maximum, max(minimum, value))
    }
}
