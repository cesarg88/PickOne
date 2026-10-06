import Foundation
import Synchronization
import UIKit

enum UITestingHomeArtwork {
    static let posterPath = "/home-poster-fixture.png"
    static let brightBackdropPath = "/home-bright-backdrop-fixture.png"
    static let darkBackdropPath = "/home-dark-backdrop-fixture.png"
    static let providerLogoPaths = [
        "/home-netflix-logo.png", "/home-prime-logo.png",
        "/home-disney-logo.png", "/home-max-logo.png",
    ]

    @MainActor
    static func primeProviderLogos(in cache: ImageCache) {
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemTeal, .systemPurple]
        for (path, color) in zip(providerLogoPaths, colors) {
            guard let url = ImageURLBuilder.providerLogoURL(path: path) else { continue }
            cache.insert(image(color: color, size: CGSize(width: 64, height: 64)), for: url)
        }
    }

    @MainActor
    static func primePoster(in cache: ImageCache) {
        guard let url = ImageURLBuilder.posterURL(path: posterPath, size: .posterLarge) else { return }
        cache.insert(image(color: .white, size: CGSize(width: 200, height: 300)), for: url)
    }

    @MainActor
    static func primeBackdrop(in cache: ImageCache, bright: Bool) {
        let path = bright ? brightBackdropPath : darkBackdropPath
        guard let url = ImageURLBuilder.backdropURL(path: path) else { return }
        let color: UIColor = bright ? .white
            : UIColor(red: 0.2, green: 0.38, blue: 0.48, alpha: 1)
        cache.insert(image(color: color, size: CGSize(width: 600, height: 400)), for: url)
    }

    @MainActor
    private static func image(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

actor UITestingThreeForTonightUseCase: ThreeForTonightUseCase {
    private var currentMovieID = 101

    func load() async throws -> ThreeForTonightResult {
        if AppConfiguration.usesHomeCompositionScenarioForUITests {
            return try .usable(Self.compositionSnapshot())
        }
        return try .usable(Self.snapshot(movieID: currentMovieID))
    }

    func refresh() async throws -> ThreeForTonightResult {
        if AppConfiguration.usesHomeCompositionScenarioForUITests {
            return try .usable(Self.compositionSnapshot())
        }
        return try .usable(Self.snapshot(movieID: currentMovieID))
    }

    func repairAfterEligibilityChange(
        _ change: DecisionEligibilityChange
    ) async throws -> ThreeForTonightResult {
        if AppConfiguration.usesHomeCompositionScenarioForUITests {
            return try .usable(Self.compositionSnapshot())
        }
        return try .usable(Self.snapshot(movieID: currentMovieID))
    }

    func reconcileAfterViewerStateChange(
        _ change: DecisionViewerStateChange
    ) async throws -> ThreeForTonightResult {
        if AppConfiguration.usesHomeCompositionScenarioForUITests {
            return try .usable(Self.compositionSnapshot())
        }
        if change.impact != .none, change.movieID == currentMovieID {
            currentMovieID = currentMovieID == 101 ? 202 : 101
        }
        return try .usable(Self.snapshot(movieID: currentMovieID))
    }

    static func snapshot(movieID: Int) throws -> ThreeForTonightSnapshot {
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

    static func compositionSnapshot() throws -> ThreeForTonightSnapshot {
        let base = try snapshot(movieID: 101).decisionSet
        guard let baseAvailability = base.recommendations.first?.availability else {
            throw UITestingHomeScenarioError.invalidFixture
        }
        let services = AppConfiguration.usesHomeFourProvidersForUITests
            ? PilotStreamingService.allowlist
            : AppConfiguration.usesHomeTwoProvidersForUITests
            ? Array(PilotStreamingService.allowlist.prefix(2)) : [PilotStreamingService.netflix]
        let providerEvidence = try DecisionAvailabilitySnapshot(
            matchingProviders: services.enumerated().map { index, service in
                try DecisionProviderSnapshot(
                    providerID: service.providerID,
                    name: service.name,
                    logoPath: services.count == 1 ? "/missing-provider-logo.png"
                        : UITestingHomeArtwork.providerLogoPaths[index],
                    productOrder: service.productOrder
                )
            },
            verifiedAt: baseAvailability.verifiedAt,
            regionalWatchURL: baseAvailability.regionalWatchURL
        )
        let allMovies: [(Int, DecisionRole, String)] = if AppConfiguration.usesHomeReferenceCopyForUITests {
            Locale.current.language.languageCode?.identifier == "es"
                ? [
                    (101, .safeChoice, "La llegada"),
                    (202, .stretchChoice, "Puñales por la espalda"),
                    (303, .discoveryChoice, "Ex Machina"),
                ]
                : [
                    (101, .safeChoice, "Arrival"),
                    (202, .stretchChoice, "Knives Out"),
                    (303, .discoveryChoice, "Ex Machina"),
                ]
        } else {
            [
                (101, .safeChoice, "An Extremely Long Movie Title That Wraps Across Several Lines"),
                (202, .stretchChoice, "Another Long Movie Title for Tonight"),
                (303, .discoveryChoice, "A Less Obvious Movie Worth Considering"),
            ]
        }
        let movies = AppConfiguration.usesHomeTwoCardsForUITests
            ? Array(allMovies.prefix(2)) : allMovies
        let recommendations = try movies.map { movie in
            try PersistedDecisionRecommendation(
                role: movie.1,
                evidence: RecommendationEvidence(primary: .sparseQuality, diversity: nil),
                display: DecisionDisplaySnapshot(
                    movieID: movie.0,
                    localizedTitle: movie.2,
                    posterPath: movie.0 == 101 && AppConfiguration.usesHomePosterScenarioForUITests
                        ? UITestingHomeArtwork.posterPath : nil,
                    backdropPath: movie.0 == 101 ? compositionBackdropPath : nil,
                    runtimeMinutes: 112,
                    releaseYear: 2024,
                    genres: []
                ),
                availability: providerEvidence
            )
        }
        let cycle = try DecisionCycle(
            id: base.cycle.id,
            identitySignature: base.cycle.identitySignature,
            shownMovieIDs: Set(movies.map(\.0))
        )
        let set = try PersistedDecisionSet(
            id: base.id,
            generatedAt: base.generatedAt,
            engineModelVersion: base.engineModelVersion,
            cycle: cycle,
            sourceViewerStateSnapshotID: base.sourceViewerStateSnapshotID,
            region: base.region,
            selectedProviderIDs: services.map(\.providerID),
            recommendations: recommendations
        )
        return ThreeForTonightSnapshot(decisionSet: set, savedMovieIDs: [])
    }

    private static var compositionBackdropPath: String? {
        if AppConfiguration.usesHomeBrightBackdropForUITests {
            return UITestingHomeArtwork.brightBackdropPath
        }
        if AppConfiguration.usesHomeDarkBackdropForUITests {
            return UITestingHomeArtwork.darkBackdropPath
        }
        return nil
    }
}

struct UITestingMovieDetailUseCase: GetMovieDetailUseCase {
    func execute(
        id: Int,
        policy: CachePolicy,
        contentLocale _: MovieContentLocale
    ) async throws -> CacheResult<MovieDetailSnapshot> {
        try await execute(id: id, policy: policy)
    }

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

actor UITestingCancellationFailureRepository: ViewingDecisionRepository {
    private let base: any ViewingDecisionRepository
    private var hasFailed = false

    init(base: any ViewingDecisionRepository) {
        self.base = base
    }

    func snapshot() async throws -> ViewingDecisionState {
        try await base.snapshot()
    }

    func apply(_ operation: ViewingDecisionOperation) async throws -> ViewingDecisionReceipt {
        if case .cancel = operation.action, !hasFailed {
            hasFailed = true
            throw ViewingDecisionError.unavailable
        }
        return try await base.apply(operation)
    }
}
