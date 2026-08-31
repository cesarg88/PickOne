import Foundation
@testable import PickOne
import Testing

@Suite("Calibration catalog integration")
struct CalibrationCatalogIntegrationTests {
    @Test("first calibration freezes and resumes the exact resolved snapshot")
    func firstCalibrationFreezesExactSnapshot() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let files = InMemoryLocalViewerStateFileStore()
        let repository = LocalViewerProfileRepositoryAdapter(
            repository: repository(files: files, ids: [firstID])
        )
        var movies = CalibrationCatalogTestFixtures.snapshot().movies
        movies[0] = CalibrationCatalogTestFixtures.replacing(
            movies[0],
            localizedTitle: "Remote title"
        )
        let snapshot = CalibrationCatalogTestFixtures.snapshot(version: 2, movies: movies)
        var draft = try await repository.beginFirstOnboarding(catalog: .spainHouseholdV1)
        draft = FirstOnboardingDraft(
            catalog: draft.catalog,
            step: .services,
            selectedServices: [.netflix],
            reactions: [:],
            currentCatalogPosition: 0,
            optionalExtensionAccepted: false
        )
        try await repository.saveFirstOnboardingDraft(draft)

        let frozen = try await repository.beginCalibration(from: draft, snapshot: snapshot)

        #expect(frozen.catalog == snapshot.catalog)
        let persisted = try #require(activeEnvelope(files).viewerProfileState.profileDraft)
        #expect(persisted.frozenCatalog.reference.version == 2)
        #expect(persisted.frozenCatalog.updatedAt == snapshot.updatedAt)
        #expect(persisted.frozenCatalog.movies[0].titleKnownInSpain == "Remote title")
        let relaunched = LocalViewerProfileRepositoryAdapter(
            repository: self.repository(files: files, ids: [])
        )
        #expect(await relaunched.loadState() == .firstOnboarding(frozen))
    }

    @Test("pre-PR9 service draft decodes as not yet frozen")
    func existingServiceDraftRemainsCompatible() async throws {
        let firstID = try LocalViewerStateTestFixtures.uuid(LocalViewerStateTestFixtures.firstID)
        let envelope = LocalViewerStateTestFixtures.envelope(
            id: firstID,
            profileDraft: LocalViewerStateTestFixtures.profileDraft(
                catalogReference: LocalViewerStateTestFixtures.catalogReference()
            )
        )
        let encoded = try LocalViewerStateTestFixtures.encoded(envelope)
        var root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var profileState = try #require(root["viewerProfileState"] as? [String: Any])
        var draft = try #require(profileState["profileDraft"] as? [String: Any])
        draft["catalogIsFrozen"] = nil
        profileState["profileDraft"] = draft
        root["viewerProfileState"] = profileState
        let legacyBytes = try JSONSerialization.data(withJSONObject: root)
        let repository = LocalViewerProfileRepositoryAdapter(
            repository: repository(
                files: InMemoryLocalViewerStateFileStore(activeData: legacyBytes),
                ids: []
            )
        )

        guard case let .firstOnboarding(loaded) = await repository.loadState() else {
            Issue.record("Expected a compatible first-onboarding draft")
            return
        }
        #expect(loaded.step == .services)
        #expect(!loaded.isCatalogFrozen)
    }

    private func repository(
        files: InMemoryLocalViewerStateFileStore,
        ids: [UUID]
    ) -> LocalViewerStateRepository {
        let sequence = SequenceUUIDGenerator(ids)
        return LocalViewerStateRepository(
            fileStore: files,
            legacySource: InMemoryLegacyViewerStateSource(),
            snapshotID: { sequence.next() },
            now: { LocalViewerStateTestFixtures.laterDate }
        )
    }

    private func activeEnvelope(
        _ files: InMemoryLocalViewerStateFileStore
    ) throws -> LocalViewerStateEnvelopeV2DTO {
        try JSONLocalViewerStateEnvelopeCoder().decode(#require(files.activeData))
    }
}
