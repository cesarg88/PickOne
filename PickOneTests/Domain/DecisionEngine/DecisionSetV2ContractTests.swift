import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set v2 contract")
struct DecisionSetV2ContractTests {
    @Test("a publishable Decision Set carries its Viewer State source identity")
    func sourceSnapshotIdentity() throws {
        let sourceID = ViewerStateSnapshotID(rawValue: UUID())
        let signature = try #require(
            DecisionCycleSignature(rawValue: String(repeating: "a", count: 64))
        )

        let decisionSet = try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature
            ),
            sourceViewerStateSnapshotID: sourceID,
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: []
        )

        #expect(decisionSet.sourceViewerStateSnapshotID == sourceID)
    }

    @Test("new persisted evidence rejects genre signals without readable labels")
    func persistedEvidenceRequiresReadableGenreLabels() throws {
        let unnamedGenre = DecisionGenre(id: 18)
        let anchor = PositiveAnchorEvidence(
            movieID: 20,
            movieTitle: "Anchor",
            reaction: .loved,
            anchorGenres: [unnamedGenre],
            sharedGenres: [unnamedGenre],
            eraMatch: nil
        )
        let affinity = PositiveAffinityEvidence(genres: [unnamedGenre], era: nil)
        let primaryEvidence: [RecommendationPrimaryEvidence] = [
            .positiveAnchor(anchor),
            .watchlistIntent(match: .positiveAnchor(anchor)),
            .positiveGenreAffinity(affinity),
            .watchlistIntent(match: .positiveAffinity(affinity)),
        ]

        for primary in primaryEvidence {
            #expect(throws: DecisionSetValidationError.invalidEvidence) {
                try PersistedDecisionRecommendation(
                    role: .safeChoice,
                    evidence: RecommendationEvidence(
                        primary: primary,
                        diversity: nil
                    ),
                    display: DecisionDisplaySnapshot(
                        movieID: 10,
                        localizedTitle: "Movie 10",
                        posterPath: nil,
                        backdropPath: nil,
                        runtimeMinutes: 100,
                        releaseYear: 2024,
                        genres: [unnamedGenre]
                    ),
                    availability: DecisionAvailabilitySnapshot(
                        matchingProviders: [DecisionProviderSnapshot(
                            providerID: PilotStreamingService.netflix.providerID,
                            name: PilotStreamingService.netflix.name,
                            logoPath: nil,
                            productOrder: PilotStreamingService.netflix.productOrder
                        )],
                        verifiedAt: Date(timeIntervalSince1970: 1000),
                        regionalWatchURL: nil
                    )
                )
            }
        }
    }
}
