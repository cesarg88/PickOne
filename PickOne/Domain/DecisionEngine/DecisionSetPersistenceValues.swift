import Foundation

enum DecisionEngineModelVersion: String, Equatable, Sendable {
    case p1Model = "P1"
}

enum DecisionViewingContext: String, Equatable, Sendable {
    case milestone6DefaultV1 = "milestone-6-default-v1"
}

struct DecisionIdentityReaction: Equatable, Sendable {
    let movieID: Int
    let reaction: CalibrationReaction
}

struct DecisionCycleIdentity: Equatable, Sendable {
    let engineModelVersion: DecisionEngineModelVersion
    let profileSchemaVersion: Int
    let calibrationCatalogVersion: String
    let region: ViewingRegion
    let selectedProviderIDs: [Int]
    let reactions: [DecisionIdentityReaction]
    let viewingContext: DecisionViewingContext

    init(
        engineModelVersion: DecisionEngineModelVersion,
        profile: ViewerProfile,
        viewingContext: DecisionViewingContext = .milestone6DefaultV1
    ) {
        self.engineModelVersion = engineModelVersion
        profileSchemaVersion = profile.profileSchemaVersion
        calibrationCatalogVersion = profile.catalogID.rawValue
        region = profile.region
        selectedProviderIDs = Array(Set(profile.selectedServices.map(\.providerID))).sorted()
        reactions = profile.reactions
            .map { DecisionIdentityReaction(movieID: $0.key, reaction: $0.value) }
            .sorted { $0.movieID < $1.movieID }
        self.viewingContext = viewingContext
    }
}

struct DecisionCycleSignature: Equatable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        let normalized = rawValue.lowercased()
        guard
            normalized.count == 64,
            normalized.unicodeScalars.allSatisfy({
                CharacterSet(charactersIn: "0123456789abcdef").contains($0)
            })
        else {
            return nil
        }
        self.rawValue = normalized
    }
}

struct DecisionCycle: Equatable, Sendable {
    let id: UUID
    let identitySignature: DecisionCycleSignature
    let shownMovieIDs: Set<Int>

    init(
        id: UUID,
        identitySignature: DecisionCycleSignature,
        shownMovieIDs: Set<Int> = []
    ) throws {
        guard shownMovieIDs.allSatisfy({ $0 > 0 }) else {
            throw DecisionSetValidationError.invalidMovieIdentity
        }
        self.id = id
        self.identitySignature = identitySignature
        self.shownMovieIDs = shownMovieIDs
    }

    func presenting(movieIDs: [Int]) throws -> DecisionCycle {
        guard movieIDs.allSatisfy({ $0 > 0 }) else {
            throw DecisionSetValidationError.invalidMovieIdentity
        }
        return try DecisionCycle(
            id: id,
            identitySignature: identitySignature,
            shownMovieIDs: shownMovieIDs.union(movieIDs)
        )
    }
}

struct DecisionDisplaySnapshot: Equatable, Sendable {
    let movieID: Int
    let localizedTitle: String
    let posterPath: String?
    let backdropPath: String?
    let runtimeMinutes: Int?
    let releaseYear: Int?
    let genres: [DecisionGenre]

    init(
        movieID: Int,
        localizedTitle: String,
        posterPath: String?,
        backdropPath: String?,
        runtimeMinutes: Int?,
        releaseYear: Int?,
        genres: [DecisionGenre]
    ) throws {
        let title = localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard movieID > 0, !title.isEmpty else {
            throw DecisionSetValidationError.invalidMovieIdentity
        }
        guard runtimeMinutes.map({ $0 > 0 }) ?? true else {
            throw DecisionSetValidationError.invalidDisplaySnapshot
        }
        guard releaseYear.map({ $0 > 0 }) ?? true else {
            throw DecisionSetValidationError.invalidDisplaySnapshot
        }
        guard
            genres.allSatisfy({ $0.id > 0 }),
            Set(genres.map(\.id)).count == genres.count
        else {
            throw DecisionSetValidationError.invalidDisplaySnapshot
        }

        self.movieID = movieID
        self.localizedTitle = title
        self.posterPath = Self.normalize(posterPath)
        self.backdropPath = Self.normalize(backdropPath)
        self.runtimeMinutes = runtimeMinutes
        self.releaseYear = releaseYear
        self.genres = genres.sorted { $0.id < $1.id }
    }

    private static func normalize(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }
}

struct DecisionProviderSnapshot: Equatable, Sendable {
    let providerID: Int
    let name: String
    let logoPath: String?
    let productOrder: Int

    init(providerID: Int, name: String, logoPath: String?, productOrder: Int) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let canonical = PilotStreamingService.allowlist.first(where: { $0.providerID == providerID }),
            normalizedName == canonical.name,
            productOrder == canonical.productOrder
        else {
            throw DecisionSetValidationError.invalidProviderEvidence
        }
        self.providerID = providerID
        self.name = normalizedName
        self.logoPath = logoPath
        self.productOrder = productOrder
    }
}

struct DecisionAvailabilitySnapshot: Equatable, Sendable {
    let matchingProviders: [DecisionProviderSnapshot]
    let verifiedAt: Date
    let regionalWatchURL: URL?

    init(
        matchingProviders: [DecisionProviderSnapshot],
        verifiedAt: Date,
        regionalWatchURL: URL?
    ) throws {
        guard
            !matchingProviders.isEmpty,
            Set(matchingProviders.map(\.providerID)).count == matchingProviders.count
        else {
            throw DecisionSetValidationError.invalidProviderEvidence
        }
        if let regionalWatchURL {
            guard
                regionalWatchURL.scheme?.lowercased() == "https",
                let host = regionalWatchURL.host?.lowercased(),
                host == "themoviedb.org" || host == "www.themoviedb.org"
            else {
                throw DecisionSetValidationError.invalidProviderEvidence
            }
        }
        self.matchingProviders = matchingProviders.sorted {
            ($0.productOrder, $0.providerID) < ($1.productOrder, $1.providerID)
        }
        self.verifiedAt = verifiedAt
        self.regionalWatchURL = regionalWatchURL
    }
}

struct PersistedDecisionRecommendation: Equatable, Sendable {
    let role: DecisionRole
    let evidence: RecommendationEvidence
    let display: DecisionDisplaySnapshot
    let availability: DecisionAvailabilitySnapshot

    init(
        role: DecisionRole,
        evidence: RecommendationEvidence,
        display: DecisionDisplaySnapshot,
        availability: DecisionAvailabilitySnapshot
    ) throws {
        try self.init(
            role: role,
            evidence: evidence,
            display: display,
            availability: availability,
            requiresReadableGenreEvidence: true
        )
    }

    static func restoringLegacyEvidence(
        role: DecisionRole,
        evidence: RecommendationEvidence,
        display: DecisionDisplaySnapshot,
        availability: DecisionAvailabilitySnapshot
    ) throws -> Self {
        try Self(
            role: role,
            evidence: evidence,
            display: display,
            availability: availability,
            requiresReadableGenreEvidence: false
        )
    }

    private init(
        role: DecisionRole,
        evidence: RecommendationEvidence,
        display: DecisionDisplaySnapshot,
        availability: DecisionAvailabilitySnapshot,
        requiresReadableGenreEvidence: Bool
    ) throws {
        try evidence.validateForPersistence(
            role: role,
            display: display,
            requiresReadableGenreEvidence: requiresReadableGenreEvidence
        )
        self.role = role
        self.evidence = evidence
        self.display = display
        self.availability = availability
    }
}

struct PersistedDecisionSet: Equatable, Sendable {
    let id: UUID
    let generatedAt: Date
    let engineModelVersion: DecisionEngineModelVersion
    let cycle: DecisionCycle
    let sourceViewerStateSnapshotID: ViewerStateSnapshotID
    let region: ViewingRegion
    let selectedProviderIDs: [Int]
    let recommendations: [PersistedDecisionRecommendation]

    init(
        id: UUID,
        generatedAt: Date,
        engineModelVersion: DecisionEngineModelVersion,
        cycle: DecisionCycle,
        sourceViewerStateSnapshotID: ViewerStateSnapshotID,
        region: ViewingRegion,
        selectedProviderIDs: [Int],
        recommendations: [PersistedDecisionRecommendation]
    ) throws {
        let normalizedProviderIDs = try Self.validateContents(
            cycle: cycle,
            region: region,
            selectedProviderIDs: selectedProviderIDs,
            recommendations: recommendations
        )

        self.id = id
        self.generatedAt = generatedAt
        self.engineModelVersion = engineModelVersion
        self.cycle = cycle
        self.sourceViewerStateSnapshotID = sourceViewerStateSnapshotID
        self.region = region
        self.selectedProviderIDs = normalizedProviderIDs
        self.recommendations = recommendations
    }

    fileprivate static func validateContents(
        cycle: DecisionCycle,
        region: ViewingRegion,
        selectedProviderIDs: [Int],
        recommendations: [PersistedDecisionRecommendation]
    ) throws -> [Int] {
        let movieIDs = recommendations.map(\.display.movieID)
        let expectedRoles = Array(
            [DecisionRole.safeChoice, .stretchChoice, .discoveryChoice]
                .prefix(recommendations.count)
        )
        let normalizedProviderIDs = Array(Set(selectedProviderIDs)).sorted()
        guard recommendations.count <= 3, recommendations.map(\.role) == expectedRoles else {
            throw DecisionSetValidationError.invalidRoleOrder
        }
        guard Set(movieIDs).count == movieIDs.count, Set(movieIDs).isSubset(of: cycle.shownMovieIDs) else {
            throw DecisionSetValidationError.invalidShownHistory
        }
        try Self.validateDiversity(in: recommendations)
        let allowlistedProviderIDs = Set(PilotStreamingService.allowlist.map(\.providerID))
        guard
            region == .spain,
            !normalizedProviderIDs.isEmpty,
            normalizedProviderIDs.allSatisfy(allowlistedProviderIDs.contains),
            recommendations.allSatisfy({ recommendation in
                Set(recommendation.availability.matchingProviders.map(\.providerID))
                    .isSubset(of: Set(normalizedProviderIDs))
            })
        else {
            throw DecisionSetValidationError.invalidProviderEvidence
        }
        return normalizedProviderIDs
    }

    private static func validateDiversity(
        in recommendations: [PersistedDecisionRecommendation]
    ) throws {
        for (index, recommendation) in recommendations.enumerated()
            where recommendation.evidence.diversity != nil
        {
            let currentGenres = Set(recommendation.display.genres)
            let priorGenreSets = recommendations[..<index]
                .map { Set($0.display.genres) }
                .filter { !$0.isEmpty }
            guard
                !currentGenres.isEmpty,
                !priorGenreSets.isEmpty,
                !priorGenreSets.contains(currentGenres)
            else {
                throw DecisionSetValidationError.invalidEvidence
            }
        }
    }
}

struct DecisionSetMigrationSource: Equatable, Sendable {
    let cycle: DecisionCycle

    init(
        cycle: DecisionCycle,
        region: ViewingRegion,
        selectedProviderIDs: [Int],
        recommendations: [PersistedDecisionRecommendation]
    ) throws {
        _ = try PersistedDecisionSet.validateContents(
            cycle: cycle,
            region: region,
            selectedProviderIDs: selectedProviderIDs,
            recommendations: recommendations
        )
        self.cycle = cycle
    }
}

enum DecisionSetValidationError: Error, Equatable, Sendable {
    case invalidMovieIdentity
    case invalidDisplaySnapshot
    case invalidProviderEvidence
    case invalidRoleOrder
    case invalidShownHistory
    case invalidEvidence
}

private extension RecommendationEvidence {
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

private extension PositiveAnchorEvidence {
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

private extension PositiveAffinityEvidence {
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

private extension DecisionDisplaySnapshot {
    var releaseDecade: DecisionDecade? {
        DecisionDecade(releaseYear: releaseYear)
    }
}

private extension DecisionDecade {
    func validateForPersistence() throws {
        guard startingYear > 0, startingYear.isMultiple(of: 10) else {
            throw DecisionSetValidationError.invalidEvidence
        }
    }
}
