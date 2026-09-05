import Foundation

enum M7P0ClosureUITestingScenario {
    private static let activeStateKey = "ui_testing_m7_p0_viewer_state_active"
    private static let previousStateKey = "ui_testing_m7_p0_viewer_state_previous"
    private static let quarantineStateKey = "ui_testing_m7_p0_viewer_state_quarantine"
    private static let currentHomeMovieIDKey = "ui_testing_m7_p0_home_movie_id"
    private static let searchHistoryKey = "search_history"

    static func makeViewerStateFileStore() -> any LocalViewerStateFileStore {
        let store = UITestingPersistentViewerStateFileStore(
            activeKey: activeStateKey,
            previousKey: previousStateKey,
            quarantineKey: quarantineStateKey
        )
        if AppConfiguration.cleansM7P0ClosureScenarioForUITests {
            try? store.removeAllViewerState()
            UserDefaults.standard.removeObject(forKey: currentHomeMovieIDKey)
            UserDefaults.standard.removeObject(forKey: searchHistoryKey)
        } else if AppConfiguration.resetsM7P0ClosureScenarioForUITests {
            try? store.removeAllViewerState()
            if let data = try? legacyViewerStateData() {
                try? store.replaceActive(with: data)
            }
            UserDefaults.standard.set(101, forKey: currentHomeMovieIDKey)
            UserDefaults.standard.set(["Sanitized Query"], forKey: searchHistoryKey)
        }
        return store
    }

    static func makeHomeUseCase() -> any ThreeForTonightUseCase {
        M7P0ClosureHomeUseCase(
            currentMovieIDKey: currentHomeMovieIDKey
        )
    }

    private static func legacyViewerStateData() throws -> Data {
        let snapshotID = try requiredUUID("70000000-0000-0000-0000-000000000001")
        let envelope = LocalViewerStateEnvelopeV2DTO(
            envelopeSchemaVersion: LocalViewerStateEnvelopeV2DTO.schemaVersion,
            committedStateSnapshotID: snapshotID,
            viewerProfileState: LocalViewerProfileStateV2DTO(
                completedProfile: CompletedViewerProfileV2DTO(
                    profileSchemaVersion: CompletedViewerProfileV2DTO.schemaVersion,
                    lastCompletedCatalogReference: CalibrationCatalogReferenceV2DTO(
                        schemaVersion: 1,
                        catalogID: "es-household-calibration",
                        version: 1,
                        regionCode: "ES",
                        localeIdentifier: "es-ES"
                    ),
                    regionCode: ViewingRegion.spain.code,
                    selectedProviderIDs: [PilotStreamingService.netflix.providerID]
                ),
                profileDraft: nil
            ),
            viewerMovieStates: [
                ViewerMovieStateV2DTO(
                    movieID: 303,
                    title: "Saved for later",
                    releaseYear: 2023,
                    posterPath: nil,
                    watchState: "unwatched",
                    preference: nil,
                    watchlistAddedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
                ),
                ViewerMovieStateV2DTO(
                    movieID: 601,
                    title: "Previously watched",
                    releaseYear: 2022,
                    posterPath: nil,
                    watchState: "watched",
                    preference: nil,
                    watchlistAddedAt: nil,
                    stateChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
                ),
            ],
            migrationRecord: LocalViewerStateMigrationRecordV2DTO(
                source: .legacyMigration,
                resolvedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        return try JSONLocalViewerStateEnvelopeCoder().encodeLegacyV2(envelope)
    }

    private static func requiredUUID(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw M7P0ClosureUITestingError.invalidFixture
        }
        return uuid
    }
}

private struct UITestingPersistentViewerStateFileStore: LocalViewerStateFileStore {
    let activeKey: String
    let previousKey: String
    let quarantineKey: String

    func readActive() throws -> Data? {
        UserDefaults.standard.data(forKey: activeKey)
    }

    func readPrevious() throws -> Data? {
        UserDefaults.standard.data(forKey: previousKey)
    }

    func replaceActive(with data: Data) throws {
        UserDefaults.standard.set(data, forKey: activeKey)
    }

    func replacePrevious(with data: Data) throws {
        UserDefaults.standard.set(data, forKey: previousKey)
    }

    func removePrevious() throws {
        UserDefaults.standard.removeObject(forKey: previousKey)
    }

    func quarantine(_ data: Data, source _: LocalViewerStateQuarantineSource) throws {
        UserDefaults.standard.set(data, forKey: quarantineKey)
    }

    func removeAllViewerState() throws {
        UserDefaults.standard.removeObject(forKey: activeKey)
        UserDefaults.standard.removeObject(forKey: previousKey)
        UserDefaults.standard.removeObject(forKey: quarantineKey)
    }
}

private actor M7P0ClosureHomeUseCase: ThreeForTonightUseCase {
    private let currentMovieIDKey: String

    init(currentMovieIDKey: String) {
        self.currentMovieIDKey = currentMovieIDKey
    }

    func load() async throws -> ThreeForTonightResult {
        try .usable(UITestingThreeForTonightUseCase.snapshot(movieID: currentMovieID))
    }

    func refresh() async throws -> ThreeForTonightResult {
        try .usable(UITestingThreeForTonightUseCase.snapshot(movieID: currentMovieID))
    }

    func repairAfterEligibilityChange(
        _: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        try .usable(UITestingThreeForTonightUseCase.snapshot(movieID: currentMovieID))
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        if change.impact != .none, change.movieID == currentMovieID {
            currentMovieID = currentMovieID == 101 ? 202 : 101
        }
        return try .usable(UITestingThreeForTonightUseCase.snapshot(movieID: currentMovieID))
    }

    private var currentMovieID: Int {
        get {
            let persisted = UserDefaults.standard.integer(forKey: currentMovieIDKey)
            return persisted > 0 ? persisted : 101
        }
        set {
            UserDefaults.standard.set(newValue, forKey: currentMovieIDKey)
        }
    }
}

private enum M7P0ClosureUITestingError: Error {
    case invalidFixture
}
