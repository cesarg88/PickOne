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
}

enum PersistedDecisionSetOutcome: Equatable, Sendable {
    case recommendations
    case exhausted(exhaustedAt: Date)
}
