struct P1DecisionEngine: DecisionSelecting, Sendable {
    func select(from input: DecisionEngineInput) -> DecisionSelection {
        select(from: rankedCandidates(from: input))
    }

    func rankedCandidates(
        from input: DecisionEngineInput,
        allowingShownMovieIDs: Set<Int> = []
    ) -> [RankedDecisionCandidate] {
        let calibrationWatchedMovieIDs = Set(
            input.profile.evidence
                .filter(\.reaction.meansWatchedInCalibration)
                .map(\.movieID)
        )
        let watchedMovieIDs = calibrationWatchedMovieIDs.union(
            input.watchlistWatchedMovieIDs
        )
        return input.candidates.compactMap { candidate in
            scoreEligibleCandidate(
                candidate,
                input: input,
                watchedMovieIDs: watchedMovieIDs,
                allowingShownMovieIDs: allowingShownMovieIDs
            )
        }
    }

    func select(
        from rankedCandidates: [RankedDecisionCandidate]
    ) -> DecisionSelection {
        var remaining = rankedCandidates
        var selected: [RankedDecisionCandidate] = []
        var recommendations: [DecisionRecommendation] = []

        for role in [DecisionRole.safeChoice, .stretchChoice, .discoveryChoice] {
            guard !remaining.isEmpty else {
                break
            }

            remaining.sort {
                isPreferred($0, over: $1, selected: selected)
            }
            let winner = remaining.removeFirst()
            let diversity = diversityEvidence(
                for: winner,
                role: role,
                selected: selected
            )
            recommendations.append(DecisionRecommendation(
                candidate: winner.candidate,
                role: role,
                evidence: RecommendationEvidence(
                    primary: winner.primaryEvidence,
                    diversity: diversity
                )
            ))
            selected.append(winner)
        }

        return DecisionSelection(recommendations: recommendations)
    }

    private func scoreEligibleCandidate(
        _ candidate: DecisionCandidate,
        input: DecisionEngineInput,
        watchedMovieIDs: Set<Int>,
        allowingShownMovieIDs: Set<Int>
    ) -> RankedDecisionCandidate? {
        guard
            !watchedMovieIDs.contains(candidate.movieID),
            allowingShownMovieIDs.contains(candidate.movieID)
            || !input.currentCycleShownMovieIDs.contains(candidate.movieID),
            candidate.availability == .eligible
        else {
            return nil
        }

        let isSavedAndUnwatched = input.savedUnwatchedMovieIDs.contains(
            candidate.movieID
        )
        let score = P1Scoring.score(
            P1CandidateScoreInput(
                movieID: candidate.movieID,
                genres: candidate.genres,
                releaseYear: candidate.releaseYear,
                voteAverage: candidate.voteAverage,
                voteCount: candidate.voteCount,
                isSavedAndUnwatched: isSavedAndUnwatched
            ),
            profile: input.profile
        )
        guard
            score.isCredible,
            let primaryEvidence = primaryEvidence(
                for: candidate,
                score: score,
                profile: input.profile,
                isSavedAndUnwatched: isSavedAndUnwatched
            )
        else {
            return nil
        }

        return RankedDecisionCandidate(
            candidate: candidate,
            score: score,
            primaryEvidence: primaryEvidence
        )
    }

    private func primaryEvidence(
        for candidate: DecisionCandidate,
        score: P1Score,
        profile: P1TasteProfile,
        isSavedAndUnwatched: Bool
    ) -> RecommendationPrimaryEvidence? {
        let anchor = strongestPositiveAnchor(for: candidate, profile: profile)
        let affinity = positiveAffinity(for: candidate, profile: profile)
        let tasteEvidence: RecommendationTasteEvidence? = if let anchor {
            .positiveAnchor(anchor)
        } else if affinity.hasSupportedSignal {
            .positiveAffinity(affinity)
        } else {
            nil
        }

        if isSavedAndUnwatched, let tasteEvidence {
            return .watchlistIntent(match: tasteEvidence)
        }
        if let anchor {
            return .positiveAnchor(anchor)
        }
        if !affinity.genres.isEmpty {
            return .positiveGenreAffinity(affinity)
        }
        if score.profileConfidence < 1.0 / 3.0, score.qualityComponent >= 0.60 {
            return .sparseQuality
        }
        return nil
    }

    private func strongestPositiveAnchor(
        for candidate: DecisionCandidate,
        profile: P1TasteProfile
    ) -> PositiveAnchorEvidence? {
        profile.evidence
            .compactMap { anchor -> RankedAnchor? in
                guard
                    let title = anchor.movieTitle,
                    let reaction = positiveAnchorReaction(anchor.reaction)
                else {
                    return nil
                }

                let similarity = P1Scoring.positiveAnchorSimilarity(
                    candidateGenres: candidate.genres,
                    releaseYear: candidate.releaseYear,
                    anchor: anchor
                )
                let genreJaccard = P1Scoring.genreJaccard(
                    candidate.genres,
                    anchor.genres
                )
                guard genreJaccard >= 1.0 / 3.0 else {
                    return nil
                }

                let sharedGenreIDs = candidate.genres
                    .intersection(anchor.genres)
                    .map(\.id)
                    .sorted()
                let sharedGenres = sharedGenreIDs.compactMap { genreID in
                    readableGenre(id: genreID, in: anchor.genres)
                }
                guard sharedGenres.count == sharedGenreIDs.count else {
                    return nil
                }
                let anchorGenres = anchor.genres.sorted { $0.id < $1.id }
                return RankedAnchor(
                    similarity: similarity,
                    evidence: PositiveAnchorEvidence(
                        movieID: anchor.movieID,
                        movieTitle: title,
                        reaction: reaction,
                        anchorGenres: anchorGenres,
                        sharedGenres: sharedGenres,
                        eraMatch: eraMatch(
                            candidateYear: candidate.releaseYear,
                            anchorYear: anchor.releaseYear
                        )
                    )
                )
            }
            .max {
                if $0.similarity != $1.similarity {
                    return $0.similarity < $1.similarity
                }
                return $0.evidence.movieID > $1.evidence.movieID
            }?.evidence
    }

    private func positiveAffinity(
        for candidate: DecisionCandidate,
        profile: P1TasteProfile
    ) -> PositiveAffinityEvidence {
        let genres = candidate.genres
            .map { genre in
                (genreID: genre.id, affinity: P1Scoring.affinity(for: genre, in: profile))
            }
            .filter { $0.affinity > 0.05 }
            .sorted {
                if $0.affinity != $1.affinity {
                    return $0.affinity > $1.affinity
                }
                return $0.genreID < $1.genreID
            }
            .compactMap { match in
                readableGenre(id: match.genreID, in: profile)
            }
        let era = candidate.releaseYear
            .flatMap(DecisionDecade.init(releaseYear:))
            .flatMap { decade in
                P1Scoring.affinity(for: decade, in: profile) > 0.05
                    ? decade
                    : nil
            }

        return PositiveAffinityEvidence(genres: genres, era: era)
    }

    private func readableGenre(
        id: Int,
        in genres: Set<DecisionGenre>
    ) -> DecisionGenre? {
        genres
            .filter { $0.id == id }
            .compactMap(\.name)
            .min()
            .map { DecisionGenre(id: id, name: $0) }
    }

    private func readableGenre(
        id: Int,
        in profile: P1TasteProfile
    ) -> DecisionGenre? {
        profile.evidence
            .flatMap(\.genres)
            .filter { $0.id == id }
            .compactMap(\.name)
            .min()
            .map { DecisionGenre(id: id, name: $0) }
    }

    private func positiveAnchorReaction(
        _ reaction: CalibrationReaction
    ) -> PositiveAnchorReaction? {
        switch reaction {
            case .loveIt: .loved
            case .likeIt: .liked
            case .itWasOkay, .didNotLikeIt, .haveNotSeenIt, .doNotKnowIt: nil
        }
    }

    private func eraMatch(
        candidateYear: Int?,
        anchorYear: Int?
    ) -> RecommendationEraMatch? {
        guard
            let candidate = DecisionDecade(releaseYear: candidateYear),
            let anchor = DecisionDecade(releaseYear: anchorYear)
        else {
            return nil
        }

        let difference = abs(candidate.startingYear - anchor.startingYear)
        switch difference {
            case 0: return .sameDecade(candidate)
            case 10: return .adjacentDecade(candidate: candidate, anchor: anchor)
            default: return nil
        }
    }

    func isPreferred(
        _ first: RankedDecisionCandidate,
        over second: RankedDecisionCandidate,
        selected: [RankedDecisionCandidate]
    ) -> Bool {
        let firstSelectionScore = selectionScore(first, selected: selected)
        let secondSelectionScore = selectionScore(second, selected: selected)
        if firstSelectionScore != secondSelectionScore {
            return firstSelectionScore > secondSelectionScore
        }
        if first.score.qualityComponent != second.score.qualityComponent {
            return first.score.qualityComponent > second.score.qualityComponent
        }
        return first.candidate.movieID < second.candidate.movieID
    }

    private func selectionScore(
        _ candidate: RankedDecisionCandidate,
        selected: [RankedDecisionCandidate]
    ) -> Double {
        let maximumOverlap = selected
            .map {
                P1Scoring.genreJaccard(
                    candidate.candidate.genres,
                    $0.candidate.genres
                )
            }
            .max() ?? 0
        return candidate.score.rankScore - 10.0 * maximumOverlap
    }

    private func diversityEvidence(
        for candidate: RankedDecisionCandidate,
        role: DecisionRole,
        selected: [RankedDecisionCandidate]
    ) -> RecommendationDiversityEvidence? {
        guard
            role != .safeChoice,
            !candidate.candidate.genres.isEmpty,
            selected.contains(where: { !$0.candidate.genres.isEmpty })
        else {
            return nil
        }

        let maximumOverlap = selected
            .map {
                P1Scoring.genreJaccard(
                    candidate.candidate.genres,
                    $0.candidate.genres
                )
            }
            .max() ?? 0
        guard maximumOverlap < 1 else {
            return nil
        }
        return .diverseDirection
    }
}

struct RankedDecisionCandidate {
    let candidate: DecisionCandidate
    let score: P1Score
    let primaryEvidence: RecommendationPrimaryEvidence
}

private struct RankedAnchor {
    let similarity: Double
    let evidence: PositiveAnchorEvidence
}

private extension PositiveAffinityEvidence {
    var hasSupportedSignal: Bool {
        !genres.isEmpty || era != nil
    }
}
