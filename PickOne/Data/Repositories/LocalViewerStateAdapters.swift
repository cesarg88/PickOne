import Foundation

struct LocalViewerProfileRepositoryAdapter: ViewerProfileRepository {
    private let repository: LocalViewerStateRepository

    init(repository: LocalViewerStateRepository) {
        self.repository = repository
    }

    func loadState() async -> ViewerProfileLoadState {
        await repository.loadProfileState()
    }

    func beginFirstOnboarding(
        catalog: CalibrationCatalog
    ) async throws -> FirstOnboardingDraft {
        try await repository.beginFirstOnboardingProfile(catalog: catalog)
    }

    func saveFirstOnboardingDraft(
        _ draft: FirstOnboardingDraft
    ) async throws {
        try await repository.saveFirstOnboardingProfileDraft(draft)
    }

    func completeFirstOnboarding() async throws -> ViewerProfile {
        try await repository.completeFirstOnboardingProfile()
    }

    func beginRecalibration(
        catalog: CalibrationCatalog
    ) async throws -> RecalibrationDraft {
        try await repository.beginRecalibrationProfile(catalog: catalog)
    }

    func saveRecalibrationDraft(
        _ draft: RecalibrationDraft
    ) async throws {
        try await repository.saveRecalibrationProfileDraft(draft)
    }

    func completeRecalibration() async throws -> ViewerProfile {
        try await repository.completeRecalibrationProfile()
    }

    func updateServices(
        _ services: [PilotStreamingService]
    ) async throws -> ViewerProfile {
        try await repository.updateProfileServices(services)
    }

    func resetDraft() async throws {
        try await repository.resetProfileDraft()
    }

    func resetProfileAndDraft() async throws {
        try await repository.resetProfilePreferences()
    }
}

struct LocalViewerStateWatchlistAdapter: WatchlistRepository {
    private let repository: LocalViewerStateRepository

    init(repository: LocalViewerStateRepository) {
        self.repository = repository
    }

    func loadAllItems() async throws -> [WatchlistItem] {
        try await repository.loadWatchlistProjection()
    }

    func add(movie: MovieSummary) async throws {
        try await repository.addToWatchlist(movie: movie)
    }

    func remove(movieId: Int) async throws {
        try await repository.removeFromWatchlist(movieID: movieId)
    }

    func setWatched(movieId: Int, isWatched: Bool) async throws {
        try await repository.setWatchlistWatched(
            movieID: movieId,
            isWatched: isWatched
        )
    }

    func getStatus(movieId: Int) async throws -> WatchlistStatus {
        try await repository.watchlistStatus(movieID: movieId)
    }
}

struct ViewerStateRecoveryNoticeAdapter: ViewerStateRecoveryNoticeRepository {
    private let repository: LocalViewerStateRepository

    init(repository: LocalViewerStateRepository) {
        self.repository = repository
    }

    func recoveryNotice() async -> ViewerStateRecoveryNotice? {
        await repository.successfulRecoveryNotice()
    }
}

struct ViewerStateDestructiveRecoveryAdapter:
    ViewerStateDestructiveRecoveryRepository
{
    private let repository: LocalViewerStateRepository

    init(repository: LocalViewerStateRepository) {
        self.repository = repository
    }

    func resetUnrecoverableViewerState() async throws {
        try await repository.resetUnrecoverableViewerState()
    }
}
