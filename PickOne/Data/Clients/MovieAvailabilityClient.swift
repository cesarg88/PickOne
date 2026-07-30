import Foundation

protocol MovieAvailabilityClientProtocol: Sendable {
    func getWatchProviders(movieID: Int) async throws -> WatchProvidersResponseDTO
}

final class MovieAvailabilityClient: MovieAvailabilityClientProtocol {
    private let httpClient: HTTPClient
    private let apiKey: String

    init(httpClient: HTTPClient, apiKey: String) {
        self.httpClient = httpClient
        self.apiKey = apiKey
    }

    func getWatchProviders(movieID: Int) async throws -> WatchProvidersResponseDTO {
        try await httpClient.request(
            endpoint: "movie/\(movieID)/watch/providers",
            method: .get,
            parameters: nil,
            headers: ["Authorization": "Bearer \(apiKey)"],
            timeout: nil,
            body: nil
        )
    }
}
