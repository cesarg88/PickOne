import Foundation

protocol ResolveCalibrationCatalogUseCase: Sendable {
    func prefetch(region: String, locale: String) async

    func execute(
        region: String,
        locale: String,
        deadline: Date
    ) async throws -> CalibrationCatalogResolution
}

struct ResolveCalibrationCatalog: ResolveCalibrationCatalogUseCase {
    private let repository: any CalibrationCatalogRepository

    init(repository: any CalibrationCatalogRepository) {
        self.repository = repository
    }

    func prefetch(region: String, locale: String) async {
        await repository.prefetch(region: region, locale: locale)
    }

    func execute(
        region: String,
        locale: String,
        deadline: Date
    ) async throws -> CalibrationCatalogResolution {
        try await repository.resolve(
            region: region,
            locale: locale,
            deadline: deadline
        )
    }
}
