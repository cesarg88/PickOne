//
//  NetworkError.swift
//  PickOne
//
//  Network layer error definitions
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(statusCode: Int)
    case apiError(message: String)
    case timeout
    case noConnection
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .apiError(let message):
            return "API error: \(message)"
        case .timeout:
            return "Request timeout"
        case .noConnection:
            return "No internet connection"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
