import Foundation
import Synchronization

actor UITestingThreeForTonightUseCase: ThreeForTonightUseCase {
    private var currentMovieID = 101

    func load() async throws -> ThreeForTonightResult {
        try .usable(Self.snapshot(movieID: currentMovieID))
    }

    func refresh() async throws -> ThreeForTonightResult {
        try .usable(Self.snapshot(movieID: currentMovieID))
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        try .usable(Self.snapshot(movieID: currentMovieID))
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        if change.impact != .none, change.movieID == currentMovieID {
            currentMovieID = currentMovieID == 101 ? 202 : 101
        }
        return try .usable(Self.snapshot(movieID: currentMovieID))
    }

    private static func snapshot(movieID: Int) throws -> ThreeForTonightSnapshot {
        guard
            let signature = DecisionCycleSignature(
                rawValue: String(repeating: "a", count: 64)
            ),
            let cycleID = UUID(uuidString: "00000000-0000-0000-0000-000000000101"),
            let decisionSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")
        else {
            throw UITestingHomeScenarioError.invalidFixture
        }
        let genre = DecisionGenre(id: 18, name: "Drama")
        let recommendation = try PersistedDecisionRecommendation(
            role: .safeChoice,
            evidence: RecommendationEvidence(
                primary: .sparseQuality,
                diversity: nil
            ),
            display: DecisionDisplaySnapshot(
                movieID: movieID,
                localizedTitle: movieID == 101 ? "Tonight's Movie" : "Replacement Movie",
                posterPath: nil,
                backdropPath: nil,
                runtimeMinutes: 112,
                releaseYear: 2024,
                genres: [genre]
            ),
            availability: DecisionAvailabilitySnapshot(
                matchingProviders: [
                    DecisionProviderSnapshot(
                        providerID: PilotStreamingService.netflix.providerID,
                        name: PilotStreamingService.netflix.name,
                        logoPath: nil,
                        productOrder: PilotStreamingService.netflix.productOrder
                    ),
                ],
                verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                regionalWatchURL: nil
            )
        )
        let cycle = try DecisionCycle(
            id: cycleID,
            identitySignature: signature,
            shownMovieIDs: [recommendation.display.movieID]
        )
        let set = try PersistedDecisionSet(
            id: decisionSetID,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engineModelVersion: .p1Model,
            cycle: cycle,
            sourceViewerStateSnapshotID: ViewerStateSnapshotID(rawValue: decisionSetID),
            region: .spain,
            selectedProviderIDs: [PilotStreamingService.netflix.providerID],
            recommendations: [recommendation]
        )
        return ThreeForTonightSnapshot(decisionSet: set, savedMovieIDs: [])
    }
}

struct UITestingMovieDetailUseCase: GetMovieDetailUseCase {
    func execute(
        id: Int,
        policy: CachePolicy
    ) async throws -> CacheResult<MovieDetailSnapshot> {
        let movie = Movie(
            id: id,
            title: title(for: id),
            originalTitle: title(for: id),
            overview: "A deterministic movie-detail fixture for UI coverage.",
            releaseDate: nil,
            runtime: 112,
            rating: 8,
            voteCount: 10000,
            posterPath: nil,
            backdropPath: nil,
            genres: [Genre(id: 18, name: "Drama")],
            tagline: nil
        )
        return CacheResult(
            value: MovieDetailSnapshot(
                movie: movie,
                similar: id == 101
                    ? [
                        MovieSummary(
                            id: 202,
                            title: "Similar Movie",
                            posterPath: nil,
                            releaseYear: 2023,
                            rating: 7.5
                        ),
                    ]
                    : [],
                director: nil,
                topCast: [],
                isSimilarUnavailable: false,
                isCreditsUnavailable: false,
                asOf: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            isStale: false
        )
    }

    private func title(for movieID: Int) -> String {
        switch movieID {
            case 101: "Tonight's Movie"
            case 202: "Replacement Movie"
            default: "Similar Movie"
        }
    }
}

actor UITestingHomeFeedbackUpdate: UpdateViewerMovieStateUseCase {
    private let base: any UpdateViewerMovieStateUseCase
    private var shouldFailNextUpdate: Bool

    init(
        base: any UpdateViewerMovieStateUseCase,
        failsFirstUpdate: Bool
    ) {
        self.base = base
        shouldFailNextUpdate = failsFirstUpdate
    }

    func execute(
        transition: ViewerMovieStateTransition,
        metadata: MovieFeedbackMetadata
    ) async throws -> ViewerMovieStateChange {
        if shouldFailNextUpdate {
            shouldFailNextUpdate = false
            throw UITestingHomeScenarioError.feedbackWriteFailed
        }
        return try await base.execute(
            transition: transition,
            metadata: metadata
        )
    }
}

final class UITestingViewerStateFileStore: LocalViewerStateFileStore {
    private struct State: Sendable {
        var active: Data?
        var previous: Data?
    }

    private let state = Mutex(State())

    func readActive() throws -> Data? {
        state.withLock { $0.active }
    }

    func readPrevious() throws -> Data? {
        state.withLock { $0.previous }
    }

    func replaceActive(with data: Data) throws {
        state.withLock { $0.active = data }
    }

    func replacePrevious(with data: Data) throws {
        state.withLock { $0.previous = data }
    }

    func removePrevious() throws {
        state.withLock { $0.previous = nil }
    }

    func quarantine(_: Data, source _: LocalViewerStateQuarantineSource) throws {}

    func removeAllViewerState() throws {
        state.withLock {
            $0.active = nil
            $0.previous = nil
        }
    }
}

struct UITestingEmptyLegacyViewerStateSource: LegacyViewerStateSource {
    func readProfile() throws -> Data? {
        nil
    }

    func readWatchlist() throws -> Data? {
        nil
    }
}

struct UITestingAvailabilityUseCase: CheckMovieAvailabilityUseCase {
    func execute(
        movieID: Int,
        policy: AvailabilityFetchPolicy
    ) async throws -> AvailabilityOutcome {
        .unknown(reason: .regionalEvidenceMissing)
    }
}

struct UITestingPreparePlaybackOptionsUseCase: PreparePlaybackOptionsUseCase {
    func execute(
        movieID: Int,
        currentOutcome: AvailabilityOutcome
    ) async throws -> PlaybackOptionsPreparation {
        .unavailable
    }
}

private enum UITestingHomeScenarioError: Error {
    case invalidFixture
    case feedbackWriteFailed
}
