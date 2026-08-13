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

    @Test("schema-valid cross-snapshot contradictions are quarantined as corrupt")
    func compositeEvidenceRecovery() async throws {
        let coder = JSONDecisionSetEnvelopeCoder()
        let envelope = try await validEnvelope()
        let safe = try #require(envelope.recommendations.first)
        let stretch = try #require(envelope.recommendations.dropFirst().first)
        let anchor = try #require(safe.evidence.anchor)
        let safeGenre = try #require(safe.display.genres.first)
        let stretchGenre = try #require(stretch.display.genres.first)
        let contradictions = try compositeContradictions(
            in: envelope,
            safe: safe,
            stretch: stretch,
            anchor: anchor,
            safeGenre: safeGenre,
            stretchGenre: stretchGenre
        )

        for invalid in contradictions {
            let bytes = try coder.encodeEnvelope(invalid)
            let store = InMemoryDecisionSetDataStore(activeData: bytes)

            #expect(await DefaultDecisionSetRepository(store: store).load() == .recovery(.corruptData))
            #expect(store.activeData == bytes)
            #expect(store.quarantineData == bytes)
        }
    }

    private func compositeContradictions(
        in envelope: DecisionSetEnvelopeV1DTO,
        safe: PersistedDecisionRecommendationV1DTO,
        stretch: PersistedDecisionRecommendationV1DTO,
        anchor: PositiveAnchorEvidenceV1DTO,
        safeGenre: DecisionGenreV1DTO,
        stretchGenre: DecisionGenreV1DTO
    ) throws -> [DecisionSetEnvelopeV1DTO] {
        let safeProvider = try #require(safe.availability.matchingProviders.first)
        return [
            replacingRecommendation(
                in: envelope,
                at: 0,
                with: replacingEvidence(
                    in: safe,
                    with: replacingAnchor(in: safe.evidence, anchor: replacing(anchor, sharedGenres: [stretchGenre]))
                )
            ),
            replacingRecommendation(
                in: envelope,
                at: 0,
                with: replacingEvidence(
                    in: safe,
                    with: replacingAnchor(
                        in: safe.evidence,
                        anchor: replacing(
                            anchor,
                            eraMatch: RecommendationEraMatchV1DTO(
                                kind: "sameDecade",
                                candidateStartingYear: nil,
                                anchorStartingYear: 2010
                            )
                        )
                    )
                )
            ),
            replacingRecommendation(
                in: envelope,
                at: 0,
                with: replacingEvidence(
                    in: safe,
                    with: replacingAnchor(
                        in: safe.evidence,
                        anchor: replacing(anchor, movieID: safe.display.movieID)
                    )
                )
            ),
            replacingRecommendation(
                in: envelope,
                at: 1,
                with: PersistedDecisionRecommendationV1DTO(
                    role: stretch.role,
                    evidence: RecommendationEvidenceV1DTO(
                        primaryKind: "positiveGenreAffinity",
                        tasteKind: nil,
                        anchor: nil,
                        affinity: PositiveAffinityEvidenceV1DTO(
                            genres: [safeGenre],
                            eraStartingYear: 2020
                        ),
                        diversityKind: "diverseDirection"
                    ),
                    display: replacingGenres(in: stretch.display, with: [safeGenre]),
                    availability: stretch.availability
                )
            ),
            replacingRecommendation(
                in: envelope,
                at: 0,
                with: PersistedDecisionRecommendationV1DTO(
                    role: safe.role,
                    evidence: safe.evidence,
                    display: safe.display,
                    availability: replacingProvider(
                        in: safe.availability,
                        with: DecisionProviderSnapshotV1DTO(
                            providerID: safeProvider.providerID,
                            name: "Disney Plus",
                            logoPath: "/tmdb-logo.jpg",
                            productOrder: 3
                        )
                    )
                )
            ),
        ]
    }

    private func validEnvelope() async throws -> DecisionSetEnvelopeV1DTO {
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        let signature = try #require(DecisionCycleSignature(rawValue: String(repeating: "a", count: 64)))
        let cycle = try DecisionCycle(id: UUID(), identitySignature: signature, shownMovieIDs: [10])
        let genre = DecisionGenre(id: 18, name: "Drama")
        let safe = try PersistedDecisionRecommendation(
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
        let comedy = DecisionGenre(id: 35, name: "Comedy")
        let stretch = try PersistedDecisionRecommendation(
            role: .stretchChoice,
            evidence: RecommendationEvidence(
                primary: .positiveGenreAffinity(
                    PositiveAffinityEvidence(genres: [comedy], era: DecisionDecade(year: 2020))
                ),
                diversity: .diverseDirection
            ),
            display: DecisionDisplaySnapshot(
                movieID: 20,
                localizedTitle: "Movie 20",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 100,
                releaseYear: 2022,
                genres: [comedy]
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
            cycle: cycle.presenting(movieIDs: [20]),
            region: .spain,
            selectedProviderIDs: [8],
            recommendations: [safe, stretch]
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
        movieID: Int? = nil,
        sharedGenres: [DecisionGenreV1DTO]? = nil,
        eraMatch: RecommendationEraMatchV1DTO? = nil
    ) -> PositiveAnchorEvidenceV1DTO {
        PositiveAnchorEvidenceV1DTO(
            movieID: movieID ?? anchor.movieID,
            movieTitle: anchor.movieTitle,
            reaction: anchor.reaction,
            sharedGenres: sharedGenres ?? anchor.sharedGenres,
            eraMatch: eraMatch
        )
    }

    private func replacingAnchor(
        in evidence: RecommendationEvidenceV1DTO,
        anchor: PositiveAnchorEvidenceV1DTO
    ) -> RecommendationEvidenceV1DTO {
        RecommendationEvidenceV1DTO(
            primaryKind: evidence.primaryKind,
            tasteKind: evidence.tasteKind,
            anchor: anchor,
            affinity: evidence.affinity,
            diversityKind: evidence.diversityKind
        )
    }

    private func replacingEvidence(
        in recommendation: PersistedDecisionRecommendationV1DTO,
        with evidence: RecommendationEvidenceV1DTO
    ) -> PersistedDecisionRecommendationV1DTO {
        PersistedDecisionRecommendationV1DTO(
            role: recommendation.role,
            evidence: evidence,
            display: recommendation.display,
            availability: recommendation.availability
        )
    }

    private func replacingRecommendation(
        in envelope: DecisionSetEnvelopeV1DTO,
        at index: Int,
        with replacement: PersistedDecisionRecommendationV1DTO
    ) -> DecisionSetEnvelopeV1DTO {
        let recommendations = envelope.recommendations.enumerated().map {
            $0.offset == index ? replacement : $0.element
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

    private func replacingGenres(
        in display: DecisionDisplaySnapshotV1DTO,
        with genres: [DecisionGenreV1DTO]
    ) -> DecisionDisplaySnapshotV1DTO {
        DecisionDisplaySnapshotV1DTO(
            movieID: display.movieID,
            localizedTitle: display.localizedTitle,
            posterPath: display.posterPath,
            backdropPath: display.backdropPath,
            runtimeMinutes: display.runtimeMinutes,
            releaseYear: display.releaseYear,
            genres: genres
        )
    }

    private func replacingProvider(
        in availability: DecisionAvailabilitySnapshotV1DTO,
        with provider: DecisionProviderSnapshotV1DTO
    ) -> DecisionAvailabilitySnapshotV1DTO {
        DecisionAvailabilitySnapshotV1DTO(
            matchingProviders: [provider],
            verifiedAt: availability.verifiedAt,
            regionalWatchURL: availability.regionalWatchURL
        )
    }
}
