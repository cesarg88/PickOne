import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set v1 migration repository")
struct DecisionSetMigrationRepositoryTests {
    @Test("valid v1 remains exact and becomes a non-publishable migration source")
    func validSource() async throws {
        let expected = try decisionSet()
        let bytes = try await legacyBytes(for: expected)
        let store = InMemoryDecisionSetDataStore(activeData: bytes)

        let result = await DefaultDecisionSetRepository(store: store).load()

        guard case let .migrationRequired(source) = result else {
            Issue.record("Expected a supported v1 migration source")
            return
        }
        #expect(source.cycle == expected.cycle)
        #expect(store.activeData == bytes)
        #expect(store.quarantineData == nil)
        #expect(store.activeReplacementCount == 0)
    }

    @Test("persisted v2 replacement completes migration across relaunch")
    func successfulRelaunch() async throws {
        let replacement = try decisionSet(snapshotID: ViewerStateSnapshotID(rawValue: UUID()))
        let legacyBytes = try await legacyBytes(for: decisionSet())
        let store = InMemoryDecisionSetDataStore(activeData: legacyBytes)
        let repository = DefaultDecisionSetRepository(store: store)
        #expect(await repository.load().isMigrationRequired)

        try await repository.replace(replacement)

        #expect(store.activeData != legacyBytes)
        #expect(
            await DefaultDecisionSetRepository(store: store).load()
                == .available(replacement)
        )
        #expect(store.quarantineData == nil)
    }

    @Test("failed v2 replacement leaves exact v1 bytes active")
    func failedReplacement() async throws {
        let bytes = try await legacyBytes(for: decisionSet())
        let store = InMemoryDecisionSetDataStore(activeData: bytes)
        let repository = DefaultDecisionSetRepository(store: store)
        #expect(await repository.load().isMigrationRequired)
        store.rejectActiveReplacements = true

        await #expect(throws: DecisionSetRepositoryError.storageFailed) {
            try await repository.replace(decisionSet())
        }

        #expect(store.activeData == bytes)
        #expect(store.quarantineData == nil)
    }

    @Test("corrupt v1 never exposes partially trusted shown history")
    func corruptSourceDoesNotExposeHistory() async throws {
        let valid = try await legacyEnvelope(for: decisionSet())
        let invalid = DecisionSetEnvelopeV1DTO(
            envelopeSchemaVersion: valid.envelopeSchemaVersion,
            decisionSetID: valid.decisionSetID,
            generatedAt: valid.generatedAt,
            engineModelVersion: valid.engineModelVersion,
            cycle: DecisionCycleV1DTO(
                id: valid.cycle.id,
                identitySignature: valid.cycle.identitySignature,
                shownMovieIDs: [-10, 99]
            ),
            regionCode: valid.regionCode,
            selectedProviderIDs: valid.selectedProviderIDs,
            recommendations: valid.recommendations
        )
        let bytes = try encodeLegacy(invalid)
        let store = InMemoryDecisionSetDataStore(activeData: bytes)

        #expect(
            await DefaultDecisionSetRepository(store: store).load()
                == .recovery(.corruptData)
        )
        #expect(store.activeData == bytes)
        #expect(store.quarantineData == bytes)
    }

    @Test("malformed v2 source identity is corrupt rather than unsupported")
    func malformedSourceIdentity() async throws {
        let expected = try decisionSet()
        let store = InMemoryDecisionSetDataStore()
        try await DefaultDecisionSetRepository(store: store).replace(expected)
        let validBytes = try #require(store.activeData)
        let validJSON = try #require(String(data: validBytes, encoding: .utf8))
        let invalidJSON = validJSON.replacingOccurrences(
            of: expected.sourceViewerStateSnapshotID.rawValue.uuidString,
            with: "not-a-uuid"
        )
        #expect(invalidJSON != validJSON)
        let bytes = Data(invalidJSON.utf8)
        let corruptStore = InMemoryDecisionSetDataStore(activeData: bytes)

        #expect(
            await DefaultDecisionSetRepository(store: corruptStore).load()
                == .recovery(.corruptData)
        )
        #expect(corruptStore.quarantineData == bytes)
    }

    private func decisionSet(
        snapshotID: ViewerStateSnapshotID = ViewerStateSnapshotID(rawValue: UUID())
    ) throws -> PersistedDecisionSet {
        let signature = try #require(
            DecisionCycleSignature(rawValue: String(repeating: "a", count: 64))
        )
        return try PersistedDecisionSet(
            id: UUID(),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engineModelVersion: .p1Model,
            cycle: DecisionCycle(
                id: UUID(),
                identitySignature: signature,
                shownMovieIDs: [10, 99]
            ),
            sourceViewerStateSnapshotID: snapshotID,
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: []
        )
    }

    private func legacyBytes(for decisionSet: PersistedDecisionSet) async throws -> Data {
        try await encodeLegacy(legacyEnvelope(for: decisionSet))
    }

    private func legacyEnvelope(
        for decisionSet: PersistedDecisionSet
    ) async throws -> DecisionSetEnvelopeV1DTO {
        let temporaryStore = InMemoryDecisionSetDataStore()
        try await DefaultDecisionSetRepository(store: temporaryStore).replace(decisionSet)
        let decoded = try JSONDecisionSetEnvelopeCoder().decodeEnvelope(
            from: #require(temporaryStore.activeData)
        )
        guard case let .currentV2(current) = decoded else {
            throw DecisionSetCodingError.corruptData
        }
        return DecisionSetEnvelopeV1DTO(
            envelopeSchemaVersion: DecisionSetEnvelopeV1DTO.schemaVersion,
            decisionSetID: current.decisionSetID,
            generatedAt: current.generatedAt,
            engineModelVersion: current.engineModelVersion,
            cycle: current.cycle,
            regionCode: current.regionCode,
            selectedProviderIDs: current.selectedProviderIDs,
            recommendations: current.recommendations
        )
    }

    private func encodeLegacy(_ legacy: DecisionSetEnvelopeV1DTO) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(legacy)
    }
}

private extension DecisionSetLoadResult {
    var isMigrationRequired: Bool {
        if case .migrationRequired = self {
            return true
        }
        return false
    }
}
