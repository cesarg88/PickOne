import Foundation

protocol CalibrationMovieMetadataClient: Sendable {
    func getMovieDetail(id: Int) async throws -> MovieDetailDTO
}

final class TMDBCalibrationMovieMetadataClient: CalibrationMovieMetadataClient {
    private let httpClient: HTTPClient
    private let apiKey: String

    init(httpClient: HTTPClient, apiKey: String) {
        self.httpClient = httpClient
        self.apiKey = apiKey
    }

    func getMovieDetail(id: Int) async throws -> MovieDetailDTO {
        try await httpClient.request(
            endpoint: "movie/\(id)",
            method: .get,
            parameters: ["language": "es-ES"],
            headers: ["Authorization": "Bearer \(apiKey)"],
            timeout: nil,
            body: nil
        )
    }
}
