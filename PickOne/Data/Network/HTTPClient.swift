//
//  HTTPClient.swift
//  PickOne
//
//  Generic HTTP client for network requests
//

import Foundation

protocol HTTPClient: Sendable {
    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: String]?,
        headers: [String: String]?,
        timeout: TimeInterval?,
        body: (any Encodable & Sendable)?
    ) async throws -> T
}

enum HTTPMethod: String, Sendable {
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

final class URLSessionHTTPClient {
    private let session: URLSession
    private let baseURL: URL
    private let responseMapper: ResponseMapper
    private let defaultTimeout: TimeInterval

    init(
        baseURL: String,
        session: URLSession = .shared,
        responseMapper: ResponseMapper = JSONResponseMapper(),
        defaultTimeout: TimeInterval = 10
    ) {
        guard let url = URL(string: baseURL) else {
            preconditionFailure("Invalid base URL: \(baseURL). This is a programmer error.")
        }
        self.baseURL = url
        self.session = session
        self.responseMapper = responseMapper
        self.defaultTimeout = defaultTimeout
    }
}

extension URLSessionHTTPClient: HTTPClient {
    // MARK: - Public Methods

    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: String]?,
        headers: [String: String]?,
        timeout: TimeInterval?,
        body: (any Encodable & Sendable)?
    ) async throws -> T {
        let url = buildURL(endpoint: endpoint, parameters: parameters)

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout ?? defaultTimeout
        if let body {
            request.httpBody = try encodeBody(body)
            if request.value(forHTTPHeaderField: Header.contentType) == nil {
                request.setValue(MIMEType.json, forHTTPHeaderField: Header.contentType)
            }
        }

        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if request.value(forHTTPHeaderField: Header.contentType) == nil {
            request.setValue(MIMEType.json, forHTTPHeaderField: Header.contentType)
        }
        if request.value(forHTTPHeaderField: Header.accept) == nil {
            request.setValue(MIMEType.json, forHTTPHeaderField: Header.accept)
        }
        #if DEBUG
            logRequest(request, endpoint: endpoint)
        #endif
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "Invalid response type", code: -1))
            }

            #if DEBUG
                logResponse(httpResponse, data: data)
            #endif

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            if request.value(forHTTPHeaderField: Header.accept)?.contains(MIMEType.json) == true {
                validateContentType(httpResponse)
            }
            guard !data.isEmpty else {
                throw NetworkError.noData
            }
            return try responseMapper.map(data, to: T.self)

        } catch let error as NetworkError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError {
            if Task.isCancelled, urlError.code == .cancelled {
                throw CancellationError()
            }
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}

private extension URLSessionHTTPClient {
    // MARK: - Private Helpers

    func buildURL(endpoint: String, parameters: [String: String]?) -> URL {
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        let url = baseURL.appending(path: normalizedEndpoint)

        guard let parameters, !parameters.isEmpty else {
            return url
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url ?? url
    }

    func validateContentType(_ response: HTTPURLResponse) {
        guard let responseContentType = response.value(forHTTPHeaderField: Header.contentType) else {
            return
        }

        if !responseContentType.lowercased().contains(MIMEType.json) {
            #if DEBUG
                print("⚠️ Unexpected Content-Type: \(responseContentType)")
            #endif
        }
    }

    func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
            case .timedOut:
                .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                .noConnection
            case .cannotFindHost, .cannotConnectToHost:
                .noConnection
            default:
                .unknown(error)
        }
    }

    func encodeBody(_ body: any Encodable & Sendable) throws -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw NetworkError.encodingError(error)
        }
    }

    // MARK: - Debug Logging

    #if DEBUG
        func logRequest(_ request: URLRequest, endpoint: String) {
            print("🌐 [\(request.httpMethod ?? "?")] \(endpoint)")
            if let url = request.url {
                print("   URL: \(url.absoluteString)")
            }
        }

        func logResponse(_ response: HTTPURLResponse, data: Data) {
            let statusEmoji = (200 ... 299).contains(response.statusCode) ? "✅" : "❌"
            print("\(statusEmoji) Response: \(response.statusCode) - \(data.count) bytes")
        }
    #endif
}
