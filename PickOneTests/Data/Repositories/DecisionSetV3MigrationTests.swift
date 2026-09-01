import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set v3 migration")
struct DecisionSetV3MigrationTests {
    @Test("v2 migration preserves current recommendations and separates history")
    func nonEmptyV2Migration() async throws {
        let current = try decisionSet(movieIDs: [10, 20], allShownMovieIDs: [1, 10, 20, 99])
        let v2Bytes = try await encodedV2(current)
        let store = InMemoryDecisionSetDataStore(activeData: v2Bytes)
        let repository = DefaultDecisionSetRepository(store: store)

        let loaded = await repository.load()
        guard case let .migrationRequired(source) = loaded,
              let migrated = try source.migratingV2(
                  suppressionEpochID: RecommendationSuppressionEpochID(rawValue: UUID())
              )
        else {
            Issue.record("Expected a supported v2 migration source")
            return
        }

        #expect(migrated.recommendations == current.recommendations)
        #expect(migrated.cycle.history.allShownMovieIDs == [1, 10, 20, 99])
        #expect(migrated.cycle.history.recentlyShownMovieIDs == [10, 20])
        #expect(migrated.outcome == .recommendations)
        #expect(store.activeData == v2Bytes)

        try await repository.replace(migrated)

        #expect(await repository.load() == .available(migrated))
        #expect(store.activeData != v2Bytes)
    }

    @Test("empty v2 has no fabricated exhaustion timestamp and remains a recovery source")
    func emptyV2Migration() async throws {
        let shownMovieIDs = Set(1001 ... 1093)
        let current = try decisionSet(movieIDs: [], allShownMovieIDs: shownMovieIDs)
        let store = try await InMemoryDecisionSetDataStore(activeData: encodedV2(current))

        guard case let .migrationRequired(source) = await DefaultDecisionSetRepository(
            store: store
        ).load(),
            let migrated = try source.migratingV2(
                suppressionEpochID: RecommendationSuppressionEpochID(rawValue: UUID())
            )
        else {
            Issue.record("Expected a supported empty v2 migration source")
            return
        }

        #expect(migrated.recommendations.isEmpty)
        #expect(migrated.cycle.history.allShownMovieIDs == shownMovieIDs)
        #expect(migrated.cycle.history.recentlyShownMovieIDs.isEmpty)
        #expect(migrated.outcome == .recommendations)
        #expect(migrated.exhaustedAt == nil)
    }

    @Test("v3 exhausted outcome round trips with its exact completion time")
    func exhaustedRoundTrip() async throws {
        let exhaustedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let source = try decisionSet(movieIDs: [10], allShownMovieIDs: [10])
        let exhausted = try PersistedDecisionSet(
            id: source.id,
            generatedAt: source.generatedAt,
            engineModelVersion: source.engineModelVersion,
            cycle: source.cycle,
            sourceViewerStateSnapshotID: source.sourceViewerStateSnapshotID,
            outcome: .exhausted(exhaustedAt: exhaustedAt),
            region: source.region,
            selectedProviderIDs: source.selectedProviderIDs,
            recommendations: source.recommendations
        )
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)

        try await repository.replace(exhausted)

        #expect(await repository.load() == .available(exhausted))
        #expect(exhausted.exhaustedAt == exhaustedAt)
    }

    @Test("v3 rejects contradictory outcome timestamps and invalid recent ordering")
    func invalidV3Semantics() async throws {
        let source = try decisionSet(movieIDs: [10], allShownMovieIDs: [10])
        let store = InMemoryDecisionSetDataStore()
        try await DefaultDecisionSetRepository(store: store).replace(source)
        let data = try #require(store.activeData)
        guard case let .currentV3(valid) = try JSONDecisionSetEnvelopeCoder()
            .decodeEnvelope(from: data)
        else {
            throw DecisionSetCodingError.corruptData
        }
        let invalidOutcomes = [
            DecisionSetEnvelopeV3DTO(
                envelopeSchemaVersion: valid.envelopeSchemaVersion,
                decisionSetID: valid.decisionSetID,
                generatedAt: valid.generatedAt,
                engineModelVersion: valid.engineModelVersion,
                cycle: valid.cycle,
                history: valid.history,
                sourceViewerStateSnapshotID: valid.sourceViewerStateSnapshotID,
                searchPolicyVersion: valid.searchPolicyVersion,
                outcome: DecisionSetOutcomeV3DTO(
                    kind: "recommendations",
                    exhaustedAt: valid.generatedAt
                ),
                regionCode: valid.regionCode,
                selectedProviderIDs: valid.selectedProviderIDs,
                recommendations: valid.recommendations
            ),
            DecisionSetEnvelopeV3DTO(
                envelopeSchemaVersion: valid.envelopeSchemaVersion,
                decisionSetID: valid.decisionSetID,
                generatedAt: valid.generatedAt,
                engineModelVersion: valid.engineModelVersion,
                cycle: valid.cycle,
                history: RecommendationHistoryV3DTO(
                    allShownMovieIDs: valid.history.allShownMovieIDs,
                    recentlyShownMovieIDs: [10, 10],
                    suppressionEpochID: valid.history.suppressionEpochID
                ),
                sourceViewerStateSnapshotID: valid.sourceViewerStateSnapshotID,
                searchPolicyVersion: valid.searchPolicyVersion,
                outcome: valid.outcome,
                regionCode: valid.regionCode,
                selectedProviderIDs: valid.selectedProviderIDs,
                recommendations: valid.recommendations
            ),
        ]

        for invalid in invalidOutcomes {
            let bytes = try JSONDecisionSetEnvelopeCoder().encodeEnvelope(invalid)
            let invalidStore = InMemoryDecisionSetDataStore(activeData: bytes)

            #expect(
                await DefaultDecisionSetRepository(store: invalidStore).load()
                    == .recovery(.corruptData)
            )
            #expect(invalidStore.quarantineData == bytes)
        }
    }

    private func decisionSet(
        movieIDs: [Int],
        allShownMovieIDs: Set<Int>
    ) throws -> PersistedDecisionSet {
        let signature = try #require(
            DecisionCycleSignature(rawValue: String(repeating: "a", count: 64))
        )
        let roles: [DecisionRole] = [.safeChoice, .stretchChoice, .discoveryChoice]
        let recommendations = try movieIDs.enumerated().map { index, movieID in
            try recommendation(movieID: movieID, role: roles[index])
        }
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: allShownMovieIDs
            ),
            sourceViewerStateSnapshotID: ViewerStateSnapshotID(rawValue: UUID()),
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: recommendations
        )
    }

    private func recommendation(
        movieID: Int,
        role: DecisionRole
    ) throws -> PersistedDecisionRecommendation {
        try PersistedDecisionRecommendation(
            role: role,
            evidence: RecommendationEvidence(primary: .sparseQuality, diversity: nil),
            display: DecisionDisplaySnapshot(
                movieID: movieID,
                localizedTitle: "Movie \(movieID)",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 100,
                releaseYear: 2024,
                genres: [DecisionGenre(id: 18, name: "Drama")]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [DecisionProviderSnapshot(
                    providerID: PilotStreamingService.netflix.providerID,
                    name: PilotStreamingService.netflix.name,
                    logoPath: nil,
                    productOrder: PilotStreamingService.netflix.productOrder
                )],
                verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                regionalWatchURL: nil
            )
        )
    }

    private func encodedV2(_ decisionSet: PersistedDecisionSet) async throws -> Data {
        let store = InMemoryDecisionSetDataStore()
        let repository = DefaultDecisionSetRepository(store: store)
        try await repository.replace(decisionSet)
        let v3Data = try #require(store.activeData)
        let decoded = try JSONDecisionSetEnvelopeCoder().decodeEnvelope(from: v3Data)
        guard case let .currentV3(currentEnvelope) = decoded else {
            throw DecisionSetCodingError.corruptData
        }
        let legacyEnvelope = DecisionSetEnvelopeV2DTO(
            envelopeSchemaVersion: DecisionSetEnvelopeV2DTO.schemaVersion,
            decisionSetID: currentEnvelope.decisionSetID,
            generatedAt: currentEnvelope.generatedAt,
            engineModelVersion: currentEnvelope.engineModelVersion,
            cycle: DecisionCycleV1DTO(
                id: currentEnvelope.cycle.id,
                identitySignature: currentEnvelope.cycle.identitySignature,
                shownMovieIDs: currentEnvelope.history.allShownMovieIDs
            ),
            sourceViewerStateSnapshotID: currentEnvelope.sourceViewerStateSnapshotID,
            regionCode: currentEnvelope.regionCode,
            selectedProviderIDs: currentEnvelope.selectedProviderIDs,
            recommendations: currentEnvelope.recommendations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(legacyEnvelope)
    }
}
