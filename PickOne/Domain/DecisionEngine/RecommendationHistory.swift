import Foundation

struct RecommendationSuppressionEpochID: Hashable, Sendable {
    let rawValue: UUID

    static let legacyCompatibility = Self(
        rawValue: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    )
}

enum RecommendationHistoryValidationError: Error, Equatable, Sendable {
    case invalidMovieIdentity
    case duplicateRecentMovieID
    case recentMovieMissingFromCompleteHistory
    case recentWindowExceeded
}

struct RecommendationHistory: Equatable, Sendable {
    static let recentWindowLimit = 30

    let allShownMovieIDs: Set<Int>
    let recentlyShownMovieIDs: [Int]
    let suppressionEpochID: RecommendationSuppressionEpochID

    init(
        allShownMovieIDs: Set<Int> = [],
        recentlyShownMovieIDs: [Int] = [],
        suppressionEpochID: RecommendationSuppressionEpochID
    ) throws {
        guard allShownMovieIDs.allSatisfy({ $0 > 0 }),
              recentlyShownMovieIDs.allSatisfy({ $0 > 0 })
        else {
            throw RecommendationHistoryValidationError.invalidMovieIdentity
        }
        guard Set(recentlyShownMovieIDs).count == recentlyShownMovieIDs.count else {
            throw RecommendationHistoryValidationError.duplicateRecentMovieID
        }
        guard recentlyShownMovieIDs.count <= Self.recentWindowLimit else {
            throw RecommendationHistoryValidationError.recentWindowExceeded
        }
        guard Set(recentlyShownMovieIDs).isSubset(of: allShownMovieIDs) else {
            throw RecommendationHistoryValidationError.recentMovieMissingFromCompleteHistory
        }

        self.allShownMovieIDs = allShownMovieIDs
        self.recentlyShownMovieIDs = recentlyShownMovieIDs
        self.suppressionEpochID = suppressionEpochID
    }

    func recording(movieIDs: [Int]) throws -> Self {
        guard movieIDs.allSatisfy({ $0 > 0 }) else {
            throw RecommendationHistoryValidationError.invalidMovieIdentity
        }

        var recent = recentlyShownMovieIDs
        for movieID in movieIDs {
            recent.removeAll { $0 == movieID }
            recent.append(movieID)
        }
        if recent.count > Self.recentWindowLimit {
            recent.removeFirst(recent.count - Self.recentWindowLimit)
        }

        return try Self(
            allShownMovieIDs: allShownMovieIDs.union(movieIDs),
            recentlyShownMovieIDs: recent,
            suppressionEpochID: suppressionEpochID
        )
    }

    func startingEpoch(_ epochID: RecommendationSuppressionEpochID) -> Self {
        Self(
            validatedAllShownMovieIDs: allShownMovieIDs,
            suppressionEpochID: epochID
        )
    }

    func releasingOldestSuppression(
        count: Int,
        excluding excludedMovieIDs: Set<Int>
    ) -> Self {
        guard count > 0 else { return self }
        let released = Set(
            recentlyShownMovieIDs
                .filter { !excludedMovieIDs.contains($0) }
                .prefix(count)
        )
        return Self(
            validatedAllShownMovieIDs: allShownMovieIDs,
            recentlyShownMovieIDs: recentlyShownMovieIDs.filter { !released.contains($0) },
            suppressionEpochID: suppressionEpochID
        )
    }

    private init(
        validatedAllShownMovieIDs: Set<Int>,
        recentlyShownMovieIDs: [Int],
        suppressionEpochID: RecommendationSuppressionEpochID
    ) {
        allShownMovieIDs = validatedAllShownMovieIDs
        self.recentlyShownMovieIDs = recentlyShownMovieIDs
        self.suppressionEpochID = suppressionEpochID
    }

    private init(
        validatedAllShownMovieIDs: Set<Int>,
        suppressionEpochID: RecommendationSuppressionEpochID
    ) {
        allShownMovieIDs = validatedAllShownMovieIDs
        recentlyShownMovieIDs = []
        self.suppressionEpochID = suppressionEpochID
    }
}

struct RecommendationSearchPolicyVersion: RawRepresentable, Equatable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }

    private init(validatedRawValue: String) {
        rawValue = validatedRawValue
    }

    static let boundedRecoveryV1 = Self(validatedRawValue: "bounded-recovery-v1")
}

struct RecommendationSearchPolicy: Equatable, Sendable {
    static let accepted = Self(
        version: .boundedRecoveryV1,
        normalPageRange: 1 ... 6,
        firstExpansionPageRange: 7 ... 12,
        finalExpansionPageRange: 13 ... 20,
        recentWindowSize: 30,
        rolloverStep: 3
    )

    let version: RecommendationSearchPolicyVersion
    let normalPageRange: ClosedRange<Int>
    let firstExpansionPageRange: ClosedRange<Int>
    let finalExpansionPageRange: ClosedRange<Int>
    let recentWindowSize: Int
    let rolloverStep: Int

    var stages: [RecommendationRecallStage] {
        [
            RecommendationRecallStage(kind: .normal, pageRange: normalPageRange),
            RecommendationRecallStage(
                kind: .firstExpansion,
                pageRange: firstExpansionPageRange
            ),
            RecommendationRecallStage(
                kind: .finalExpansion,
                pageRange: finalExpansionPageRange
            ),
        ]
    }
}

enum RecommendationRecallStageKind: Int, Equatable, Sendable {
    case normal
    case firstExpansion
    case finalExpansion
    case rollover
}

struct RecommendationRecallStage: Equatable, Sendable {
    let kind: RecommendationRecallStageKind
    let pageRange: ClosedRange<Int>
}

struct RecommendationExhaustionPolicy: Equatable, Sendable {
    static let accepted = Self(freshnessInterval: 24 * 60 * 60)

    let freshnessInterval: TimeInterval

    func isFresh(exhaustedAt: Date, now: Date) -> Bool {
        now < expiresAt(exhaustedAt: exhaustedAt)
    }

    func expiresAt(exhaustedAt: Date) -> Date {
        exhaustedAt.addingTimeInterval(freshnessInterval)
    }
}

enum PersistedDecisionSetOutcome: Equatable, Sendable {
    case recommendations
    case exhausted(exhaustedAt: Date)
}
