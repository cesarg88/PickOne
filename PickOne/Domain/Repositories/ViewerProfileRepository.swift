protocol ViewerProfileRepository: Sendable {
    func loadState() async -> ViewerProfileLoadState
    func beginFirstOnboarding(catalog: CalibrationCatalog) async throws -> FirstOnboardingDraft
    func saveFirstOnboardingDraft(_ draft: FirstOnboardingDraft) async throws
    func completeFirstOnboarding() async throws -> ViewerProfile
    func beginRecalibration(catalog: CalibrationCatalog) async throws -> RecalibrationDraft
    func saveRecalibrationDraft(_ draft: RecalibrationDraft) async throws
    func completeRecalibration() async throws -> ViewerProfile
    func updateServices(_ services: [PilotStreamingService]) async throws -> ViewerProfile
    func resetDraft() async throws
    func resetProfileAndDraft() async throws
}

enum ViewerProfileRepositoryError: Error, Equatable, Sendable {
    case invalidStoredState
    case invalidTransition
    case validation(ViewerProfileValidationError)
    case encodingFailed
    case storageFailed
}
