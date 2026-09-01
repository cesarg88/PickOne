import Foundation

extension RecommendationEvidence {
    func validateForPersistence(
        role: DecisionRole,
        display: DecisionDisplaySnapshot,
        requiresReadableGenreEvidence: Bool
    ) throws {
        guard role != .safeChoice || diversity == nil else {
            throw DecisionSetValidationError.invalidEvidence
        }

        switch primary {
            case let .watchlistIntent(match):
                switch match {
                    case let .positiveAnchor(anchor):
                        try anchor.validateForPersistence(
                            display: display,
                            requiresReadableGenreEvidence: requiresReadableGenreEvidence
                        )
                    case let .positiveAffinity(affinity):
                        try affinity.validateForPersistence(
                            requiresGenre: false,
                            display: display,
                            requiresReadableGenreEvidence: requiresReadableGenreEvidence
                        )
                }
            case let .positiveAnchor(anchor):
                try anchor.validateForPersistence(
                    display: display,
                    requiresReadableGenreEvidence: requiresReadableGenreEvidence
                )
            case let .positiveGenreAffinity(affinity):
                try affinity.validateForPersistence(
                    requiresGenre: true,
                    display: display,
                    requiresReadableGenreEvidence: requiresReadableGenreEvidence
                )
            case .sparseQuality:
                break
        }
    }
}

extension PositiveAnchorEvidence {
    func validateForPersistence(
        display: DecisionDisplaySnapshot,
        requiresReadableGenreEvidence: Bool
    ) throws {
        let title = movieTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayGenreIDs = Set(display.genres.map(\.id))
        let evidenceGenreIDs = Set(sharedGenres.map(\.id))
        guard
            movieID > 0,
            movieID != display.movieID,
            !title.isEmpty,
            sharedGenres.allSatisfy({ $0.id > 0 }),
            !requiresReadableGenreEvidence || sharedGenres.allSatisfy({ $0.name != nil }),
            evidenceGenreIDs.count == sharedGenres.count,
            evidenceGenreIDs.isSubset(of: displayGenreIDs),
            !sharedGenres.isEmpty || eraMatch != nil
        else {
            throw DecisionSetValidationError.invalidEvidence
        }

        if let anchorGenres {
            let anchorGenreIDs = Set(anchorGenres.map(\.id))
            let actualSharedGenreIDs = displayGenreIDs.intersection(anchorGenreIDs)
            let unionGenreIDs = displayGenreIDs.union(anchorGenreIDs)
            guard
                !anchorGenres.isEmpty,
                anchorGenres.allSatisfy({ $0.id > 0 }),
                anchorGenreIDs.count == anchorGenres.count,
                !actualSharedGenreIDs.isEmpty,
                actualSharedGenreIDs == evidenceGenreIDs,
                Double(actualSharedGenreIDs.count) / Double(unionGenreIDs.count)
                >= 1.0 / 3.0
            else {
                throw DecisionSetValidationError.invalidEvidence
            }
        }

        switch eraMatch {
            case let .sameDecade(decade):
                try decade.validateForPersistence()
                guard decade == display.releaseDecade else {
                    throw DecisionSetValidationError.invalidEvidence
                }
            case let .adjacentDecade(candidate, anchor):
                try candidate.validateForPersistence()
                try anchor.validateForPersistence()
                let difference = candidate.startingYear > anchor.startingYear
                    ? candidate.startingYear - anchor.startingYear
                    : anchor.startingYear - candidate.startingYear
                guard difference == 10, candidate == display.releaseDecade else {
                    throw DecisionSetValidationError.invalidEvidence
                }
            case nil:
                break
        }
    }
}

extension PositiveAffinityEvidence {
    func validateForPersistence(
        requiresGenre: Bool,
        display: DecisionDisplaySnapshot,
        requiresReadableGenreEvidence: Bool
    ) throws {
        let displayGenreIDs = Set(display.genres.map(\.id))
        let evidenceGenreIDs = Set(genres.map(\.id))
        guard
            genres.allSatisfy({ $0.id > 0 }),
            !requiresReadableGenreEvidence || genres.allSatisfy({ $0.name != nil }),
            evidenceGenreIDs.count == genres.count,
            evidenceGenreIDs.isSubset(of: displayGenreIDs),
            !genres.isEmpty || era != nil,
            !requiresGenre || !genres.isEmpty
        else {
            throw DecisionSetValidationError.invalidEvidence
        }
        try era?.validateForPersistence()
        guard era == nil || era == display.releaseDecade else {
            throw DecisionSetValidationError.invalidEvidence
        }
    }
}

extension DecisionDisplaySnapshot {
    var releaseDecade: DecisionDecade? {
        DecisionDecade(releaseYear: releaseYear)
    }
}

extension DecisionDecade {
    func validateForPersistence() throws {
        guard startingYear > 0, startingYear.isMultiple(of: 10) else {
            throw DecisionSetValidationError.invalidEvidence
        }
    }
}
