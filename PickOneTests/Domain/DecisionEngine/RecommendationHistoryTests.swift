import Foundation
@testable import PickOne
import Testing

@Suite("Recommendation history")
struct RecommendationHistoryTests {
    @Test("recent history is ordered, unique, bounded, and complete history is monotonic")
    func recordingHistory() throws {
        let epoch = RecommendationSuppressionEpochID(rawValue: UUID())
        var history = try RecommendationHistory(
            allShownMovieIDs: Set(1 ... 30),
            recentlyShownMovieIDs: Array(1 ... 30),
            suppressionEpochID: epoch
        )

        history = try history.recording(movieIDs: [2, 31, 32])

        #expect(history.allShownMovieIDs == Set(1 ... 32))
        #expect(history.recentlyShownMovieIDs == Array(4 ... 30) + [2, 31, 32])
        #expect(history.suppressionEpochID == epoch)
    }

    @Test("changing epoch clears recent suppression without losing complete history")
    func changingEpoch() throws {
        let history = try RecommendationHistory(
            allShownMovieIDs: [10, 20, 30],
            recentlyShownMovieIDs: [20, 30],
            suppressionEpochID: RecommendationSuppressionEpochID(rawValue: UUID())
        )
        let replacementEpoch = RecommendationSuppressionEpochID(rawValue: UUID())

        let reset = history.startingEpoch(replacementEpoch)

        #expect(reset.allShownMovieIDs == [10, 20, 30])
        #expect(reset.recentlyShownMovieIDs.isEmpty)
        #expect(reset.suppressionEpochID == replacementEpoch)
    }

    @Test("invalid recent history is rejected")
    func invalidHistory() {
        let epoch = RecommendationSuppressionEpochID(rawValue: UUID())

        #expect(throws: RecommendationHistoryValidationError.duplicateRecentMovieID) {
            _ = try RecommendationHistory(
                allShownMovieIDs: [10],
                recentlyShownMovieIDs: [10, 10],
                suppressionEpochID: epoch
            )
        }
        #expect(throws: RecommendationHistoryValidationError.recentMovieMissingFromCompleteHistory) {
            _ = try RecommendationHistory(
                allShownMovieIDs: [10],
                recentlyShownMovieIDs: [20],
                suppressionEpochID: epoch
            )
        }
        #expect(throws: RecommendationHistoryValidationError.recentWindowExceeded) {
            _ = try RecommendationHistory(
                allShownMovieIDs: Set(1 ... 31),
                recentlyShownMovieIDs: Array(1 ... 31),
                suppressionEpochID: epoch
            )
        }
    }
}
