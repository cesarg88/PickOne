protocol GetCurrentViewingContextUseCase: Sendable {
    func execute() async throws -> AvailabilityViewingContext
}

enum CurrentViewingContextError: Error, Equatable, Sendable {
    case unavailable
}

struct GetCurrentViewingContext: GetCurrentViewingContextUseCase {
    private let repository: ViewerProfileRepository

    init(repository: ViewerProfileRepository) {
        self.repository = repository
    }

    func execute() async throws -> AvailabilityViewingContext {
        guard case let .completed(profile, _) = await repository.loadState() else {
            throw CurrentViewingContextError.unavailable
        }
        return AvailabilityViewingContext(
            region: profile.region,
            selectedServices: profile.selectedServices
        )
    }
}
