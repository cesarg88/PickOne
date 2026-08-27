protocol ResetUnrecoverableViewerStateUseCase: Sendable {
    func availability() async -> DestructiveRecoveryAvailability
    func execute() async throws
}

struct ResetUnrecoverableViewerState: ResetUnrecoverableViewerStateUseCase {
    private let repository: any ViewerStateDestructiveRecoveryRepository

    init(repository: any ViewerStateDestructiveRecoveryRepository) {
        self.repository = repository
    }

    func availability() async -> DestructiveRecoveryAvailability {
        await repository.destructiveRecoveryAvailability()
    }

    func execute() async throws {
        try await repository.resetUnrecoverableViewerState()
    }
}
