//
//  NetworkError.swift
//  PickOne
//
//  Network layer error definitions
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case httpError(statusCode: Int)
    case apiError(message: String)
    case timeout
    case noConnection
    case unknown(Error)

    var errorDescription: String {
        switch self {
            case .invalidURL:
                "Invalid URL"
            case .noData:
                "No data received"
            case let .decodingError(error):
                "Failed to decode response: \(error.localizedDescription)"
            case let .encodingError(error):
                "Failed to encode request body: \(error.localizedDescription)"
            case let .httpError(statusCode):
                "HTTP error: \(statusCode)"
            case let .apiError(message):
                "API error: \(message)"
            case .timeout:
                "Request timeout"
            case .noConnection:
                "No internet connection"
            case let .unknown(error):
                "Unknown error: \(error.localizedDescription)"
        }
    }
}
