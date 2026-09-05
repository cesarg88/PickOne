import Foundation
@testable import PickOne
import Testing

@Suite("Recommendation recovery policy")
struct RecommendationRecoveryPolicyTests {
    @Test("rollover releases oldest non-active IDs three at a time")
    func oldestFirstRollover() throws {
        let history = try RecommendationHistory(
            allShownMovieIDs: Set(1 ... 8),
            recentlyShownMovieIDs: Array(1 ... 8),
            suppressionEpochID: RecommendationSuppressionEpochID(rawValue: UUID())
        )

        let first = history.releasingOldestSuppression(
            count: 3,
            excluding: [1, 4]
        )
        let second = first.releasingOldestSuppression(
            count: 3,
            excluding: [1, 4]
        )

        #expect(first.recentlyShownMovieIDs == [1, 4, 6, 7, 8])
        #expect(second.recentlyShownMovieIDs == [1, 4])
        #expect(second.allShownMovieIDs == Set(1 ... 8))
    }

    @Test("exhaustion is fresh only before the exact 24-hour boundary")
    func exhaustionFreshnessBoundary() {
        let exhaustedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let policy = RecommendationExhaustionPolicy.accepted

        #expect(policy.isFresh(
            exhaustedAt: exhaustedAt,
            now: exhaustedAt.addingTimeInterval(24 * 60 * 60 - 0.001)
        ))
        #expect(!policy.isFresh(
            exhaustedAt: exhaustedAt,
            now: exhaustedAt.addingTimeInterval(24 * 60 * 60)
        ))
        #expect(!policy.isFresh(
            exhaustedAt: exhaustedAt,
            now: exhaustedAt.addingTimeInterval(24 * 60 * 60 + 1)
        ))
        #expect(policy.expiresAt(exhaustedAt: exhaustedAt) ==
            exhaustedAt.addingTimeInterval(24 * 60 * 60))
    }

    @Test("accepted stages are deterministic 6 to 12 to 20")
    func acceptedStages() {
        let stages = RecommendationSearchPolicy.accepted.stages

        #expect(stages.map(\.pageRange) == [1 ... 6, 7 ... 12, 13 ... 20])
        #expect(stages.map(\.kind) == [.normal, .firstExpansion, .finalExpansion])
    }
}
