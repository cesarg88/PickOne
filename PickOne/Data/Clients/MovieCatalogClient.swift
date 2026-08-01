import Foundation

protocol MovieCatalogClient: Sendable {
    func getTopRated(page: Int) async throws -> MovieListResponseDTO
    func getMovieDetail(id: Int) async throws -> MovieDetailDTO
    func getSimilarMovies(id: Int, page: Int) async throws -> MovieListResponseDTO
    func searchMovies(query: String, page: Int) async throws -> SearchResponseDTO
    func getMovieCredits(id: Int) async throws -> CreditsResponseDTO
}

final class TMDBMovieCatalogClient {
    private enum Endpoint {
        case topRated
        case movieDetail(id: Int)
        case similarMovies(id: Int)
        case search
        case credits(id: Int)

        var path: String {
            switch self {
                case .topRated:
                    "movie/top_rated"
                case let .movieDetail(id):
                    "movie/\(id)"
                case let .similarMovies(id):
                    "movie/\(id)/similar"
                case .search:
                    "search/movie"
                case let .credits(id):
                    "movie/\(id)/credits"
            }
        }
    }

    private let httpClient: HTTPClient
    private let apiKey: String
    private let language: String

    init(httpClient: HTTPClient, apiKey: String, language: String = "en-US") {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.language = language
    }
}

extension TMDBMovieCatalogClient: MovieCatalogClient {
    func getTopRated(page: Int) async throws -> MovieListResponseDTO {
        try await httpClient.request(
            endpoint: Endpoint.topRated.path,
            method: .get,
            parameters: buildParameters(page: page),
            headers: authHeaders,
            timeout: nil,
            body: nil
        )
    }

    func getMovieDetail(id: Int) async throws -> MovieDetailDTO {
        try await httpClient.request(
            endpoint: Endpoint.movieDetail(id: id).path,
            method: .get,
            parameters: buildParameters(),
            headers: authHeaders,
            timeout: nil,
            body: nil
        )
    }

    func getSimilarMovies(id: Int, page: Int) async throws -> MovieListResponseDTO {
        try await httpClient.request(
            endpoint: Endpoint.similarMovies(id: id).path,
            method: .get,
            parameters: buildParameters(page: page),
            headers: authHeaders,
            timeout: nil,
            body: nil
        )
    }

    func searchMovies(query: String, page: Int) async throws -> SearchResponseDTO {
        try await httpClient.request(
            endpoint: Endpoint.search.path,
            method: .get,
            parameters: buildParameters(query: query, page: page),
            headers: authHeaders,
            timeout: nil,
            body: nil
        )
    }

    func getMovieCredits(id: Int) async throws -> CreditsResponseDTO {
        try await httpClient.request(
            endpoint: Endpoint.credits(id: id).path,
            method: .get,
            parameters: buildParameters(),
            headers: authHeaders,
            timeout: nil,
            body: nil
        )
    }

    private var authHeaders: [String: String] {
        ["Authorization": "Bearer \(apiKey)"]
    }

    private func buildParameters(query: String? = nil, page: Int? = nil) -> [String: String] {
        var params: [String: String] = [:]

        params["language"] = language

        if let query {
            params["query"] = query
        }

        if let page {
            params["page"] = "\(page)"
        }

        return params
    }
}
