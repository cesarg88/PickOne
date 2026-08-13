import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set composite validation")
struct DecisionSetCompositeValidationTests {
    @Test("recommendation evidence must agree with its display snapshot")
    func recommendationEvidenceConsistency() {
        let drama = DecisionGenre(id: 18, name: "Drama")
        let comedy = DecisionGenre(id: 35, name: "Comedy")
        let invalidEvidence = [
            RecommendationEvidence(
                primary: .positiveAnchor(
                    PositiveAnchorEvidence(
                        movieID: 155,
                        movieTitle: "Anchor",
                        reaction: .loved,
                        sharedGenres: [comedy],
                        eraMatch: nil
                    )
                ),
                diversity: nil
            ),
            RecommendationEvidence(
                primary: .positiveGenreAffinity(
                    PositiveAffinityEvidence(genres: [comedy], era: nil)
                ),
                diversity: nil
            ),
            RecommendationEvidence(
                primary: .positiveAnchor(
                    PositiveAnchorEvidence(
                        movieID: 155,
                        movieTitle: "Anchor",
                        reaction: .liked,
                        sharedGenres: [drama],
                        eraMatch: .sameDecade(DecisionDecade(year: 2010))
                    )
                ),
                diversity: nil
            ),
            RecommendationEvidence(
                primary: .positiveAnchor(
                    PositiveAnchorEvidence(
                        movieID: 10,
                        movieTitle: "Same movie",
                        reaction: .liked,
                        sharedGenres: [drama],
                        eraMatch: nil
                    )
                ),
                diversity: nil
            ),
        ]

        for evidence in invalidEvidence {
            #expect(throws: DecisionSetValidationError.invalidEvidence) {
                _ = try recommendation(
                    movieID: 10,
                    role: .safeChoice,
                    genres: [drama],
                    releaseYear: 2024,
                    evidence: evidence
                )
            }
        }
    }

    @Test("diversity evidence must be demonstrated by prior set composition")
    func diversityConsistency() throws {
        let drama = DecisionGenre(id: 18, name: "Drama")
        let safe = try recommendation(
            movieID: 10,
            role: .safeChoice,
            genres: [drama],
            releaseYear: 2024,
            evidence: .init(primary: .sparseQuality, diversity: nil)
        )
        let unsupportedStretch = try recommendation(
            movieID: 20,
            role: .stretchChoice,
            genres: [drama],
            releaseYear: 2022,
            evidence: .init(
                primary: .positiveGenreAffinity(
                    PositiveAffinityEvidence(genres: [drama], era: DecisionDecade(year: 2020))
                ),
                diversity: .diverseDirection
            )
        )

        #expect(throws: DecisionSetValidationError.invalidEvidence) {
            _ = try decisionSet(recommendations: [safe, unsupportedStretch])
        }
    }

    @Test("provider identity must match the canonical allowlist")
    func providerConsistency() {
        #expect(throws: DecisionSetValidationError.invalidProviderEvidence) {
            _ = try DecisionProviderSnapshot(
                providerID: PilotStreamingService.netflix.providerID,
                name: PilotStreamingService.disneyPlus.name,
                logoPath: "/tmdb-logo.jpg",
                productOrder: PilotStreamingService.disneyPlus.productOrder
            )
        }
    }

    private func recommendation(
        movieID: Int,
        role: DecisionRole,
        genres: [DecisionGenre],
        releaseYear: Int,
        evidence: RecommendationEvidence
    ) throws -> PersistedDecisionRecommendation {
        try PersistedDecisionRecommendation(
            role: role,
            evidence: evidence,
            display: DecisionDisplaySnapshot(
                movieID: movieID,
                localizedTitle: "Movie \(movieID)",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 100,
                releaseYear: releaseYear,
                genres: genres
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [
                    DecisionProviderSnapshot(
                        providerID: PilotStreamingService.netflix.providerID,
                        name: PilotStreamingService.netflix.name,
                        logoPath: "/tmdb-logo.jpg",
                        productOrder: PilotStreamingService.netflix.productOrder
                    ),
                ],
                verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                regionalWatchURL: nil
            )
        )
    }

    private func decisionSet(
        recommendations: [PersistedDecisionRecommendation]
    ) throws -> PersistedDecisionSet {
        let signature = try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
        let movieIDs = Set(recommendations.map(\.display.movieID))
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_001),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(id: UUID(), identitySignature: signature, shownMovieIDs: movieIDs),
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: recommendations
        )
    }
}
