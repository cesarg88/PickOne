import Foundation

protocol CalibrationCatalogRepository: Sendable {
    func prefetch(region: String, locale: String) async

    func resolve(
        region: String,
        locale: String,
        deadline: Date
    ) async throws -> CalibrationCatalogResolution
}
