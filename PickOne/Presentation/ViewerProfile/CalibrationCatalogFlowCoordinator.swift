import Foundation

@MainActor
final class CalibrationCatalogFlowCoordinator {
    private let resolver: ResolveCalibrationCatalogUseCase
    private let now: @Sendable () -> Date
    private var deadline: Date?
    private var resolutionTask: Task<CalibrationCatalogResolution, Error>?

    init(
        resolver: ResolveCalibrationCatalogUseCase,
        now: @escaping @Sendable () -> Date
    ) {
        self.resolver = resolver
        self.now = now
    }

    func prefetch() {
        if deadline == nil {
            deadline = now().addingTimeInterval(2)
        }
        let resolver = resolver
        Task { @concurrent in
            await resolver.prefetch(region: ViewingRegion.spain.code, locale: "es-ES")
        }
    }

    func resolve() async throws -> CalibrationCatalogResolution {
        if deadline == nil {
            prefetch()
        }
        let deadline = deadline ?? now()
        let resolver = resolver
        let task = Task { @concurrent in
            try await resolver.execute(
                region: ViewingRegion.spain.code,
                locale: "es-ES",
                deadline: deadline
            )
        }
        resolutionTask = task
        defer { resolutionTask = nil }
        return try await task.value
    }

    func completeFlow() {
        deadline = nil
    }

    func cancelWait() {
        resolutionTask?.cancel()
        resolutionTask = nil
    }

    func reset() {
        cancelWait()
        deadline = nil
    }
}
