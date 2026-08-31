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

    func beginCalibration(
        from draft: FirstOnboardingDraft,
        snapshot: CalibrationCatalogSnapshot?
    ) async throws -> FirstOnboardingDraft {
        try await repository.beginCalibrationProfile(
            from: draft,
            snapshot: snapshot
        )
    }

    func completeFirstOnboarding() async throws -> ViewerProfile {
        try await repository.completeFirstOnboardingProfile()
    }

    func beginRecalibration(
        snapshot: CalibrationCatalogSnapshot
    ) async throws -> RecalibrationDraft {
        try await repository.beginRecalibrationProfile(snapshot: snapshot)
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

    func setMembership(
        movie: MovieSummary,
        isInWatchlist: Bool
    ) async throws -> WatchlistMutationOutcome {
        try await repository.setWatchlistMembership(
            movie: movie,
            isInWatchlist: isInWatchlist
        )
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

    func destructiveRecoveryAvailability() async -> DestructiveRecoveryAvailability {
        await repository.destructiveRecoveryAvailability()
    }

    func resetUnrecoverableViewerState() async throws {
        try await repository.resetUnrecoverableViewerState()
    }
}
