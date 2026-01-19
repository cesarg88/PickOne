//
//  HTTPClient.swift
//  PickOne
//
//  Generic HTTP client for network requests
//

import Foundation

protocol HTTPClient {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: String]?,
        body: Data?
    ) async throws -> T
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

final class URLSessionHTTPClient: HTTPClient {
    
    private let session: URLSession
    private let baseURL: String
    
    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: String]? = nil,
        body: Data? = nil
    ) async throws -> T {
        
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        // Add query parameters
        if let parameters = parameters {
            urlComponents.queryItems = parameters.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "Invalid response", code: -1))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw NetworkError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.noConnection
            default:
                throw NetworkError.unknown(urlError)
            }
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}
