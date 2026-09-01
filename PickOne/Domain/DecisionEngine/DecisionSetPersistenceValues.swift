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
        reactions currentReactions: [Int: MovieReaction],
        viewingContext: DecisionViewingContext = .milestone6DefaultV1
    ) {
        self.engineModelVersion = engineModelVersion
        profileSchemaVersion = profile.profileSchemaVersion
        calibrationCatalogVersion = profile.catalogID.rawValue
        region = profile.region
        selectedProviderIDs = Array(Set(profile.selectedServices.map(\.providerID))).sorted()
        reactions = currentReactions
            .map {
                DecisionIdentityReaction(
                    movieID: $0.key,
                    reaction: $0.value.calibrationReaction
                )
            }
            .sorted { $0.movieID < $1.movieID }
        self.viewingContext = viewingContext
    }

    init(
        engineModelVersion: DecisionEngineModelVersion,
        profile: ViewerProfile,
        viewingContext: DecisionViewingContext = .milestone6DefaultV1
    ) {
        self.init(
            engineModelVersion: engineModelVersion,
            profile: profile,
            reactions: profile.reactions.compactMapValues { reaction in
                switch reaction {
                    case .loveIt: .loveIt
                    case .likeIt: .likeIt
                    case .itWasOkay: .itWasOkay
                    case .didNotLikeIt: .didNotLikeIt
                    case .haveNotSeenIt, .doNotKnowIt: nil
                }
            },
            viewingContext: viewingContext
        )
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
    let history: RecommendationHistory

    var shownMovieIDs: Set<Int> {
        history.allShownMovieIDs
    }

    init(
        id: UUID,
        identitySignature: DecisionCycleSignature,
        history: RecommendationHistory
    ) throws {
        self.id = id
        self.identitySignature = identitySignature
        self.history = history
    }

    init(
        id: UUID,
        identitySignature: DecisionCycleSignature,
        shownMovieIDs: Set<Int> = []
    ) throws {
        try self.init(
            id: id,
            identitySignature: identitySignature,
            history: RecommendationHistory(
                allShownMovieIDs: shownMovieIDs,
                recentlyShownMovieIDs: [],
                suppressionEpochID: .legacyCompatibility
            )
        )
    }

    func presenting(movieIDs: [Int]) throws -> DecisionCycle {
        guard movieIDs.allSatisfy({ $0 > 0 }) else {
            throw DecisionSetValidationError.invalidMovieIdentity
        }
        return try DecisionCycle(
            id: id,
            identitySignature: identitySignature,
            history: history.recording(movieIDs: movieIDs)
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
    let searchPolicyVersion: RecommendationSearchPolicyVersion
    let outcome: PersistedDecisionSetOutcome
    let region: ViewingRegion
    let selectedProviderIDs: [Int]
    let recommendations: [PersistedDecisionRecommendation]

    init(
        id: UUID,
        generatedAt: Date,
        engineModelVersion: DecisionEngineModelVersion,
        cycle: DecisionCycle,
        sourceViewerStateSnapshotID: ViewerStateSnapshotID,
        searchPolicyVersion: RecommendationSearchPolicyVersion = .boundedRecoveryV1,
        outcome: PersistedDecisionSetOutcome = .recommendations,
        region: ViewingRegion,
        selectedProviderIDs: [Int],
        recommendations: [PersistedDecisionRecommendation]
    ) throws {
        let recommendationMovieIDs = recommendations.map(\.display.movieID)
        let activeIDs = Set(recommendationMovieIDs)
        let normalizedCycle = activeIDs.isSubset(of: cycle.shownMovieIDs)
            && !activeIDs.isSubset(of: Set(cycle.history.recentlyShownMovieIDs))
            ? try cycle.presenting(movieIDs: recommendationMovieIDs)
            : cycle
        let normalizedProviderIDs = try Self.validateContents(
            cycle: normalizedCycle,
            region: region,
            selectedProviderIDs: selectedProviderIDs,
            recommendations: recommendations
        )
        if case .exhausted = outcome, recommendations.count == 3 {
            throw DecisionSetValidationError.invalidOutcome
        }

        self.id = id
        self.generatedAt = generatedAt
        self.engineModelVersion = engineModelVersion
        self.cycle = normalizedCycle
        self.sourceViewerStateSnapshotID = sourceViewerStateSnapshotID
        self.searchPolicyVersion = searchPolicyVersion
        self.outcome = outcome
        self.region = region
        self.selectedProviderIDs = normalizedProviderIDs
        self.recommendations = recommendations
    }

    var exhaustedAt: Date? {
        guard case let .exhausted(exhaustedAt) = outcome else { return nil }
        return exhaustedAt
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
    private let legacyV2: DecisionSetV2MigrationSource?

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
        legacyV2 = nil
    }

    init(legacyV2: DecisionSetV2MigrationSource) {
        cycle = legacyV2.cycle
        self.legacyV2 = legacyV2
    }

    func migratingV2(
        suppressionEpochID: RecommendationSuppressionEpochID
    ) throws -> PersistedDecisionSet? {
        try legacyV2?.migrating(suppressionEpochID: suppressionEpochID)
    }
}

struct DecisionSetV2MigrationSource: Equatable, Sendable {
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
        _ = try PersistedDecisionSet.validateContents(
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
        self.selectedProviderIDs = selectedProviderIDs
        self.recommendations = recommendations
    }

    func migrating(
        suppressionEpochID: RecommendationSuppressionEpochID
    ) throws -> PersistedDecisionSet {
        let history = try RecommendationHistory(
            allShownMovieIDs: cycle.shownMovieIDs,
            recentlyShownMovieIDs: recommendations.map(\.display.movieID),
            suppressionEpochID: suppressionEpochID
        )
        return try PersistedDecisionSet(
            id: id,
            generatedAt: generatedAt,
            engineModelVersion: engineModelVersion,
            cycle: DecisionCycle(
                id: cycle.id,
                identitySignature: cycle.identitySignature,
                history: history
            ),
            sourceViewerStateSnapshotID: sourceViewerStateSnapshotID,
            searchPolicyVersion: .boundedRecoveryV1,
            outcome: .recommendations,
            region: region,
            selectedProviderIDs: selectedProviderIDs,
            recommendations: recommendations
        )
    }
}

enum DecisionSetValidationError: Error, Equatable, Sendable {
    case invalidMovieIdentity
    case invalidDisplaySnapshot
    case invalidProviderEvidence
    case invalidRoleOrder
    case invalidShownHistory
    case invalidEvidence
    case invalidOutcome
}
