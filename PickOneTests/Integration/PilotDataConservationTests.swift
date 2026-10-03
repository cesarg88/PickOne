import Foundation
@testable import PickOne
import Testing

struct PilotDataConservationTests {
    @Test(arguments: [false, true])
    func upgradedStateSurvivesRepeatedJourneysAndMeasurementLifecycle(prune: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let suite = "PickOneTests.PilotConservation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let viewerFiles = try ApplicationSupportViewerStateStore(directoryURL: directory.appending(path: "Viewer"))
        let decisionFiles = try ApplicationSupportViewingDecisionStore(directory: directory
            .appending(path: "Measurement"))
        let legacy = try legacyEnvelope()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let original = try encoder.encode(legacy)
        try viewerFiles.replaceActive(with: original)
        let quarantine = Data("retained diagnostic bytes".utf8)
        try viewerFiles.quarantine(quarantine, source: .active)
        let homeStore = UserDefaultsDecisionSetDataStore(suiteName: suite)
        let home = try UITestingThreeForTonightUseCase.snapshot(movieID: 101).decisionSet
        try await DefaultDecisionSetRepository(store: homeStore).replace(home)
        try homeStore.replaceQuarantine(with: quarantine)
        let homeBytes = try homeStore.readActive()
        defaults.set(["Private search sentinel"], forKey: "search_history")

        let migrated = try await viewer(viewerFiles).snapshot()
        #expect(migrated.id.rawValue == legacy.committedStateSnapshotID)
        #expect(migrated.recommendationSuppressionEpochID.rawValue == legacy.recommendationSuppressionEpochID)
        #expect(migrated.states.allSatisfy { $0.pickOneProvenance == nil })
        #expect(try viewerFiles.readPrevious() == original)
        try await assertLegacyFields(viewerFiles, legacy: legacy)

        // Recreate both real file-backed repositories each evening; clocks advance without sleeps.
        for day in 0 ..< 12 {
            try await evening(day, viewerFiles: viewerFiles, decisionFiles: decisionFiles)
        }
        let repository = LocalViewingDecisionRepository(store: decisionFiles)
        let beforeLifecycle = try await repository.measurementSummary(at: moment(12 * 86400).wall)
        #expect(beforeLifecycle.confirmedWatched == 12)
        #expect(beforeLifecycle.likeIt == 12)
        #expect(beforeLifecycle.superseded == 12)
        #expect(beforeLifecycle.cancelled == 12)
        #expect(beforeLifecycle.refreshes == 12)
        #expect(beforeLifecycle.firstPickMeanSeconds == 10)
        #expect(beforeLifecycle.finalPickMeanSeconds == 40)

        // An unresolved Pick remains product state beyond the measurement retention window.
        let surface = try surface(movieID: 900)
        let pending = try #require(surface.recommendations.first)
        _ = try await repository.apply(.init(
            action: .pick(pending, snapshot: surface, isVisible: false), moment: moment(12 * 86400)
        ))
        let pendingID = try #require(try await repository.snapshot().activeDecision?.id)
        let viewerBefore = try viewerFiles.readActive()
        let previousBefore = try viewerFiles.readPrevious()
        let export = try await repository.exportMeasurement(at: moment(12 * 86400).wall)
        let text = try #require(String(data: export, encoding: .utf8))
        for excluded in [
            "Private search sentinel",
            "Historic reaction",
            "Saved movie",
            "Confirmed movie",
            "posterPath",
        ] {
            #expect(!text.contains(excluded))
        }
        let future = moment(400 * 86400).wall
        if prune {
            #expect(try await repository.measurementSummary(at: future).confirmedWatched == 0)
        } else {
            try await repository.deleteMeasurement(operationID: UUID(), at: future)
        }

        let reopened = LocalViewingDecisionRepository(store: decisionFiles)
        let summary = try await reopened.measurementSummary(at: future)
        #expect(summary.confirmedWatched == 0)
        #expect(summary.pending == 1)
        #expect(try await reopened.snapshot().activeDecision?.id == pendingID)
        #expect(try viewerFiles.readActive() == viewerBefore)
        #expect(try viewerFiles.readPrevious() == previousBefore)
        #expect(try homeStore.readActive() == homeBytes)
        #expect(try homeStore.readQuarantine() == quarantine)
        #expect(await DefaultDecisionSetRepository(store: homeStore).load() == .available(home))
        #expect(defaults.stringArray(forKey: "search_history") == ["Private search sentinel"])
        try await assertLegacyFields(viewerFiles, legacy: legacy)
        let finalViewer = try await viewer(viewerFiles).snapshot()
        #expect(finalViewer.states.count(where: { $0.pickOneProvenance != nil }) == 12)
        #expect(finalViewer.states.filter { $0.pickOneProvenance != nil }.allSatisfy { $0.reaction == .loveIt })
        let quarantineDirectory = directory.appending(path: "Viewer/Quarantine")
        let files = try FileManager.default.contentsOfDirectory(
            at: quarantineDirectory,
            includingPropertiesForKeys: nil
        )
        #expect(files.count == 1)
        #expect(try Data(contentsOf: #require(files.first)) == quarantine)
    }

    private func evening(
        _ day: Int,
        viewerFiles: ApplicationSupportViewerStateStore,
        decisionFiles: ApplicationSupportViewingDecisionStore
    ) async throws {
        let repository = LocalViewingDecisionRepository(store: decisionFiles)
        let surface = try surface(movieID: 100 + day * 2)
        let first = try #require(surface.recommendations.first)
        let last = try #require(surface.recommendations.last)
        let offset = Double(day * 86400)
        func apply(_ action: ViewingDecisionAction, _ seconds: Double) async throws {
            _ = try await repository.apply(.init(action: action, moment: moment(offset + seconds)))
        }
        try await apply(.activate(surface), 0)
        try await apply(.pick(first, snapshot: surface, isVisible: true), 10)
        try await apply(.pick(last, snapshot: surface, isVisible: true), 20)
        let cancelled = try #require(try await repository.snapshot().activeDecision?.id)
        try await apply(.cancel(cancelled), 30)
        try await apply(.pause, 30)
        try await apply(.activate(surface), 330)
        try await apply(.refresh(surface), 335)
        try await apply(.pick(first, snapshot: surface, isVisible: true), 340)
        try await apply(.pause, 350)
        let id = try #require(try await repository.snapshot().activeDecision?.id)
        let viewerBefore = try viewerFiles.readActive()
        let reopened = LocalViewingDecisionRepository(store: decisionFiles)
        #expect(try await reopened.snapshot().activeDecision?.id == id)
        #expect(try viewerFiles.readActive() == viewerBefore)
        let confirmationMoment = moment(offset + 13 * 3600, runtimeID: UUID())
        let metadata = try MovieFeedbackMetadata(title: "Confirmed movie", releaseYear: 2020, posterPath: nil)
        let coordinator = ConfirmViewingDecision(
            decisions: reopened, viewerState: viewer(viewerFiles),
            metadata: { _ in metadata }, moment: { confirmationMoment }
        )
        try await coordinator.confirm(id, operationID: UUID())
        try await coordinator.confirm(id, operationID: UUID(), reaction: .likeIt)
        _ = try await viewer(viewerFiles).apply(
            .init(movieID: first.movieID, action: .assignReaction(.loveIt)), metadata: metadata
        )
        let restored = try await LocalViewingDecisionRepository(store: decisionFiles).snapshot()
        #expect(restored.decisions.first { $0.id == id }?.satisfaction == .likeIt)
        #expect(try await viewer(viewerFiles).state(movieID: first.movieID)?.reaction == .loveIt)
    }

    private func viewer(_ files: ApplicationSupportViewerStateStore) -> LocalViewerStateRepository {
        LocalViewerStateRepository(fileStore: files, legacySource: InMemoryLegacyViewerStateSource())
    }

    private func moment(_ seconds: Double, runtimeID: UUID = ViewingDecisionTestFixtures.runtimeID) -> DecisionMoment {
        ViewingDecisionTestFixtures.moment(seconds, runtimeID: runtimeID)
    }

    private func surface(movieID: Int) throws -> ViewingDecisionSurface {
        let setID = UUID()
        let cycleID = UUID()
        return try ViewingDecisionSurface(recommendations: [
            PickRecommendation(movieID: movieID, setID: setID, cycleID: cycleID, role: .safeChoice),
            PickRecommendation(movieID: movieID + 1, setID: setID, cycleID: cycleID, role: .stretchChoice),
        ])
    }

    private func assertLegacyFields(
        _ files: ApplicationSupportViewerStateStore,
        legacy: LocalViewerStateEnvelopeV3DTO
    ) async throws {
        _ = try await viewer(files).snapshot()
        guard case let .currentV4(envelope) = try JSONLocalViewerStateEnvelopeCoder()
            .decode(#require(try files.readActive()))
        else {
            Issue.record("Expected the upgraded v4 envelope")
            return
        }
        #expect(envelope.viewerProfileState == legacy.viewerProfileState)
        #expect(envelope.migrationRecord == legacy.migrationRecord)
        for state in legacy.viewerMovieStates {
            #expect(envelope.viewerMovieStates.first { $0.movieID == state.movieID } == state)
        }
    }

    private func legacyEnvelope() throws -> LocalViewerStateEnvelopeV3DTO {
        let reference = LocalViewerStateTestFixtures.catalogReference()
        return try LocalViewerStateEnvelopeV3DTO(
            envelopeSchemaVersion: 3,
            committedStateSnapshotID: UUID(),
            recommendationSuppressionEpochID: UUID(),
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: LocalViewerStateTestFixtures.completedProfile(catalogReference: reference),
                profileDraft: nil
            ),
            viewerMovieStates: [
                LocalViewerStateEnvelopeMapper().map(ViewerMovieState(
                    movieID: 10,
                    displayMetadata: MovieFeedbackMetadata(
                        title: "Historic reaction",
                        releaseYear: 2001,
                        posterPath: nil
                    ),
                    watchState: .watched, preference: .reaction(.likeIt), watchlistIntent: nil,
                    stateChangedAt: LocalViewerStateTestFixtures.date
                )),
                ViewerMovieStateV2DTO(
                    movieID: 11, title: "Saved movie", releaseYear: 2022, posterPath: nil,
                    watchState: "unwatched", preference: nil,
                    watchlistAddedAt: LocalViewerStateTestFixtures.date,
                    stateChangedAt: LocalViewerStateTestFixtures.date
                ),
            ],
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: .legacyMigration, resolvedAt: LocalViewerStateTestFixtures.date
            )
        )
    }
}
