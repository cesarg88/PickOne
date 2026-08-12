import Foundation

protocol DecisionCandidateClient: Sendable {
    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> DecisionCandidatePageDTO
}

final class TMDBDecisionCandidateClient {
    private let httpClient: any HTTPClient
    private let apiKey: String

    init(httpClient: any HTTPClient, apiKey: String) {
        self.httpClient = httpClient
        self.apiKey = apiKey
    }
}

extension TMDBDecisionCandidateClient: DecisionCandidateClient {
    func discoverPage(
        _ page: Int,
        context: DecisionCandidateContext
    ) async throws -> DecisionCandidatePageDTO {
        try await httpClient.request(
            endpoint: "discover/movie",
            method: .get,
            parameters: parameters(page: page, context: context),
            headers: ["Authorization": "Bearer \(apiKey)"],
            timeout: nil,
            body: nil
        )
    }

    private func parameters(
        page: Int,
        context: DecisionCandidateContext
    ) -> [String: String] {
        [
            "include_adult": "false",
            "include_video": "false",
            "language": "es-ES",
            "page": String(page),
            "region": context.region.code,
            "sort_by": "popularity.desc",
            "watch_region": context.region.code,
            "with_watch_monetization_types": "flatrate",
            "with_watch_providers": context.selectedProviderIDs
                .map(String.init)
                .joined(separator: "|"),
        ]
    }
}
