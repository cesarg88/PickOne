//
//  MovieCatalogClient.swift
//  PickOne
//
//  Client for TMDB API - executes HTTP requests and returns raw DTOs
//

import Foundation

protocol MovieCatalogClientProtocol {
    func getTopRated(page: Int) async throws -> MovieListResponseDTO
    func getMovieDetail(id: Int) async throws -> MovieDetailDTO
    func getSimilarMovies(id: Int, page: Int) async throws -> MovieListResponseDTO
    func searchMovies(query: String, page: Int) async throws -> SearchResponseDTO
    func getMovieCredits(id: Int) async throws -> CreditsResponseDTO
}

final class MovieCatalogClient: MovieCatalogClientProtocol {
    
    private let httpClient: HTTPClient
    private let apiKey: String
    
    init(httpClient: HTTPClient, apiKey: String) {
        self.httpClient = httpClient
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    func getTopRated(page: Int = 1) async throws -> MovieListResponseDTO {
        return try await httpClient.request(
            endpoint: "/movie/top_rated",
            method: .get,
            parameters: [
                "api_key": apiKey,
                "page": "\(page)",
                "language": "en-US"
            ],
            body: nil
        )
    }
    
    func getMovieDetail(id: Int) async throws -> MovieDetailDTO {
        return try await httpClient.request(
            endpoint: "/movie/\(id)",
            method: .get,
            parameters: [
                "api_key": apiKey,
                "language": "en-US"
            ],
            body: nil
        )
    }
    
    func getSimilarMovies(id: Int, page: Int = 1) async throws -> MovieListResponseDTO {
        return try await httpClient.request(
            endpoint: "/movie/\(id)/similar",
            method: .get,
            parameters: [
                "api_key": apiKey,
                "page": "\(page)",
                "language": "en-US"
            ],
            body: nil
        )
    }
    
    func searchMovies(query: String, page: Int = 1) async throws -> SearchResponseDTO {
        return try await httpClient.request(
            endpoint: "/search/movie",
            method: .get,
            parameters: [
                "api_key": apiKey,
                "query": query,
                "page": "\(page)",
                "language": "en-US"
            ],
            body: nil
        )
    }
    
    func getMovieCredits(id: Int) async throws -> CreditsResponseDTO {
        return try await httpClient.request(
            endpoint: "/movie/\(id)/credits",
            method: .get,
            parameters: [
                "api_key": apiKey
            ],
            body: nil
        )
    }
}
