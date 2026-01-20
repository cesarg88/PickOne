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
        headers: [String: String]?,
        body: Data?,
        timeout: TimeInterval?,
        contentType: String?
    ) async throws -> T
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - HTTP Constants

private enum Header {
    static let contentType = "Content-Type"
    static let accept = "Accept"
}

private enum MIMEType {
    static let json = "application/json"
}

// MARK: - Implementation

final class URLSessionHTTPClient: HTTPClient {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(baseURL: String, session: URLSession = .shared) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid base URL: \(baseURL)")
        }
        self.baseURL = url
        self.session = session
        
        // Configure JSON decoder with best practices
        // Note: No dateDecodingStrategy - TMDB returns dates as "YYYY-MM-DD" strings.
        // DTOs should use String for dates, and mappers convert to Date/year as needed.
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Public Methods
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timeout: TimeInterval? = nil,
        contentType: String? = nil
    ) async throws -> T {
        
        // Build URL correctly using URL components
        let url = buildURL(endpoint: endpoint, parameters: parameters)
        
        // Build URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout ?? AppConfiguration.defaultRequestTimeout
        
        // Apply custom headers FIRST (so they can be overridden if needed)
        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Set default headers if not already set
        if request.value(forHTTPHeaderField: Header.contentType) == nil {
            request.setValue(contentType ?? MIMEType.json, forHTTPHeaderField: Header.contentType)
        }
        if request.value(forHTTPHeaderField: Header.accept) == nil {
            request.setValue(MIMEType.json, forHTTPHeaderField: Header.accept)
        }
        
        // Set body if provided
        if let body {
            request.httpBody = body
        }
        
        // Debug logging
        #if DEBUG
        logRequest(request, endpoint: endpoint)
        #endif
        
        // Execute request
        do {
            let (data, response) = try await session.data(for: request)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "Invalid response type", code: -1))
            }
            
            // Debug logging
            #if DEBUG
            logResponse(httpResponse, data: data)
            #endif
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Validate Content-Type (only if expecting JSON)
            if request.value(forHTTPHeaderField: Header.accept)?.contains(MIMEType.json) == true {
                validateContentType(httpResponse)
            }
            
            // Handle empty responses
            guard !data.isEmpty else {
                throw NetworkError.noData
            }
            
            // Decode response
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                print("❌ Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Response body: \(jsonString.prefix(500))")
                }
                #endif
                throw NetworkError.decodingError(error)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildURL(endpoint: String, parameters: [String: String]?) -> URL {
        // Normalize endpoint: remove leading slash to avoid double slashes
        // Convention: endpoints should NOT have leading slash (e.g., "3/movie/top_rated")
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        
        // Use appending(path:) for proper path construction
        let url = baseURL.appending(path: normalizedEndpoint)
        
        // Add query parameters if provided
        guard let parameters, !parameters.isEmpty else {
            return url
        }
        
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        return components.url ?? url
    }
    
    private func validateContentType(_ response: HTTPURLResponse) {
        guard let responseContentType = response.value(forHTTPHeaderField: Header.contentType) else {
            return
        }
        
        // Allow application/json or variants like application/json; charset=utf-8
        if !responseContentType.lowercased().contains(MIMEType.json) {
            #if DEBUG
            print("⚠️ Unexpected Content-Type: \(responseContentType)")
            #endif
        }
    }
    
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .cannotFindHost, .cannotConnectToHost:
            return .noConnection
        default:
            return .unknown(error)
        }
    }
    
    // MARK: - Debug Logging
    
    #if DEBUG
    private func logRequest(_ request: URLRequest, endpoint: String) {
        print("🌐 [\(request.httpMethod ?? "?")] \(endpoint)")
        if let url = request.url {
            print("   URL: \(url.absoluteString)")
        }
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("   Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("   Body: \(bodyString.prefix(200))")
        }
    }
    
    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        let statusEmoji = (200...299).contains(response.statusCode) ? "✅" : "❌"
        print("\(statusEmoji) Response: \(response.statusCode)")
        
        if let responseContentType = response.value(forHTTPHeaderField: Header.contentType) {
            print("   Content-Type: \(responseContentType)")
        }
        
        print("   Size: \(data.count) bytes")
        
        // Log first 200 chars of response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("   Body preview: \(jsonString.prefix(200))")
        }
    }
    #endif
}
