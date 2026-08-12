import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set evidence recovery")
struct DecisionSetEvidenceRecoveryTests {
    @Test("schema-valid semantically invalid evidence is quarantined as corrupt")
    func invalidEvidenceRecovery() async throws {
        let coder = JSONDecisionSetEnvelopeCoder()
        let envelope = try await validEnvelope()
        let evidence = try #require(envelope.recommendations.first?.evidence)
        let anchor = try #require(evidence.anchor)
        let genre = try #require(anchor.sharedGenres.first)
        let affinity = PositiveAffinityEvidenceV1DTO(genres: [genre], eraStartingYear: 2020)
        let invalidEvidence = [
            RecommendationEvidenceV1DTO(
                primaryKind: "positiveAnchor",
                tasteKind: nil,
                anchor: replacing(anchor, sharedGenres: [], eraMatch: nil),
                affinity: nil,
                diversityKind: nil
            ),
            RecommendationEvidenceV1DTO(
                primaryKind: "positiveGenreAffinity",
                tasteKind: nil,
                anchor: nil,
                affinity: PositiveAffinityEvidenceV1DTO(genres: [], eraStartingYear: 2020),
                diversityKind: nil
            ),
            RecommendationEvidenceV1DTO(
                primaryKind: evidence.primaryKind,
                tasteKind: evidence.tasteKind,
                anchor: anchor,
                affinity: nil,
                diversityKind: "diverseDirection"
            ),
            RecommendationEvidenceV1DTO(
                primaryKind: "positiveAnchor",
                tasteKind: nil,
                anchor: replacing(
                    anchor,
                    eraMatch: RecommendationEraMatchV1DTO(
                        kind: "sameDecade",
                        candidateStartingYear: nil,
                        anchorStartingYear: 2025
                    )
                ),
                affinity: nil,
                diversityKind: nil
            ),
            RecommendationEvidenceV1DTO(
                primaryKind: "positiveAnchor",
                tasteKind: nil,
                anchor: replacing(
                    anchor,
                    eraMatch: RecommendationEraMatchV1DTO(
                        kind: "adjacentDecade",
                        candidateStartingYear: 2020,
                        anchorStartingYear: 1990
                    )
                ),
                affinity: nil,
                diversityKind: nil
            ),
            RecommendationEvidenceV1DTO(
                primaryKind: "positiveAnchor",
                tasteKind: nil,
                anchor: anchor,
                affinity: affinity,
                diversityKind: nil
            ),
        ]

        for invalid in invalidEvidence {
            let bytes = try coder.encodeEnvelope(replacingEvidence(in: envelope, with: invalid))
            let store = InMemoryDecisionSetDataStore(activeData: bytes)

            #expect(await DefaultDecisionSetRepository(store: store).load() == .recovery(.corruptData))
            #expect(store.activeData == bytes)
            #expect(store.quarantineData == bytes)
        }
    }

    private func validEnvelope() async throws -> DecisionSetEnvelopeV1DTO {
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        let signature = try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
        let cycle = try DecisionCycle(id: UUID(), identitySignature: signature, shownMovieIDs: [10])
        let genre = DecisionGenre(id: 18, name: "Drama")
        let recommendation = try PersistedDecisionRecommendation(
            role: .safeChoice,
            evidence: RecommendationEvidence(
                primary: .positiveAnchor(
                    PositiveAnchorEvidence(
                        movieID: 155,
                        movieTitle: "Anchor",
                        reaction: .loved,
                        sharedGenres: [genre],
                        eraMatch: nil
                    )
                ),
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: 10,
                localizedTitle: "Movie 10",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 120,
                releaseYear: 2024,
                genres: [genre]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [
                    DecisionProviderSnapshot(
                        providerID: 8,
                        name: "Netflix",
                        logoPath: nil,
                        productOrder: 1
                    ),
                ],
                verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                regionalWatchURL: nil
            )
        )
        let decisionSet = try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_001),
            engineModelVersion: .p1Model,
            cycle: cycle,
            region: .spain,
            selectedProviderIDs: [8],
            recommendations: [recommendation]
        )
        try await repository.replace(decisionSet)
        return try JSONDecisionSetEnvelopeCoder().decodeEnvelope(from: #require(store.activeData))
    }

    private func replacingEvidence(
        in envelope: DecisionSetEnvelopeV1DTO,
        with evidence: RecommendationEvidenceV1DTO
    ) -> DecisionSetEnvelopeV1DTO {
        let recommendations = envelope.recommendations.enumerated().map { index, recommendation in
            guard index == 0 else { return recommendation }
            return PersistedDecisionRecommendationV1DTO(
                role: recommendation.role,
                evidence: evidence,
                display: recommendation.display,
                availability: recommendation.availability
            )
        }
        return DecisionSetEnvelopeV1DTO(
            envelopeSchemaVersion: envelope.envelopeSchemaVersion,
            decisionSetID: envelope.decisionSetID,
            generatedAt: envelope.generatedAt,
            engineModelVersion: envelope.engineModelVersion,
            cycle: envelope.cycle,
            regionCode: envelope.regionCode,
            selectedProviderIDs: envelope.selectedProviderIDs,
            recommendations: recommendations
        )
    }

    private func replacing(
        _ anchor: PositiveAnchorEvidenceV1DTO,
        sharedGenres: [DecisionGenreV1DTO]? = nil,
        eraMatch: RecommendationEraMatchV1DTO? = nil
    ) -> PositiveAnchorEvidenceV1DTO {
        PositiveAnchorEvidenceV1DTO(
            movieID: anchor.movieID,
            movieTitle: anchor.movieTitle,
            reaction: anchor.reaction,
            sharedGenres: sharedGenres ?? anchor.sharedGenres,
            eraMatch: eraMatch
        )
    }
}
