import Foundation
import Synchronization

struct CalibrationCatalogHTTPResponse: Equatable, Sendable {
    let data: Data
    let statusCode: Int
    let contentType: String?
    let finalURL: URL
}

enum CalibrationCatalogHTTPClientError: Error, Equatable, Sendable {
    case insecureEndpoint
    case responseTooLarge
    case invalidResponse
    case untrustedRedirect
    case unavailable
}

protocol CalibrationCatalogHTTPClient: Sendable {
    func get() async throws -> CalibrationCatalogHTTPResponse
}

final class HTTPSCalibrationCatalogClient: CalibrationCatalogHTTPClient, Sendable {
    private let endpoint: URL
    private let redirectPolicy: CalibrationCatalogRedirectPolicy
    private let session: URLSession
    private let maximumResponseBytes: Int

    init(
        endpoint: URL,
        session: URLSession = .shared,
        maximumResponseBytes: Int = CalibrationCatalogDocumentDecoder.maximumResponseBytes
    ) throws {
        guard endpoint.scheme?.lowercased() == "https",
              endpoint.host != nil,
              endpoint.user == nil,
              endpoint.password == nil
        else {
            throw CalibrationCatalogHTTPClientError.insecureEndpoint
        }
        self.endpoint = endpoint
        redirectPolicy = CalibrationCatalogRedirectPolicy(endpoint: endpoint)
        self.session = session
        self.maximumResponseBytes = maximumResponseBytes
    }

    func get() async throws -> CalibrationCatalogHTTPResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let redirectDelegate = CalibrationCatalogRedirectDelegate(
            policy: redirectPolicy
        )

        do {
            let (bytes, response) = try await session.bytes(
                for: request,
                delegate: redirectDelegate
            )
            guard let httpResponse = response as? HTTPURLResponse,
                  let finalURL = httpResponse.url
            else {
                throw CalibrationCatalogHTTPClientError.invalidResponse
            }
            guard !redirectDelegate.didRejectRedirect else {
                throw CalibrationCatalogHTTPClientError.untrustedRedirect
            }
            guard isTrusted(finalURL) else {
                throw CalibrationCatalogHTTPClientError.untrustedRedirect
            }
            guard httpResponse.expectedContentLength <= Int64(maximumResponseBytes) else {
                throw CalibrationCatalogHTTPClientError.responseTooLarge
            }

            var data = Data()
            if httpResponse.expectedContentLength > 0 {
                data.reserveCapacity(Int(httpResponse.expectedContentLength))
            }
            for try await byte in bytes {
                guard data.count < maximumResponseBytes else {
                    throw CalibrationCatalogHTTPClientError.responseTooLarge
                }
                data.append(byte)
            }
            return CalibrationCatalogHTTPResponse(
                data: data,
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
                finalURL: finalURL
            )
        } catch let error as CalibrationCatalogHTTPClientError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard !redirectDelegate.didRejectRedirect else {
                throw CalibrationCatalogHTTPClientError.untrustedRedirect
            }
            throw CalibrationCatalogHTTPClientError.unavailable
        }
    }

    private func isTrusted(_ url: URL) -> Bool {
        redirectPolicy.permits(url)
    }
}

private struct CalibrationCatalogRedirectPolicy: Sendable {
    private let host: String
    private let port: Int

    init(endpoint: URL) {
        host = endpoint.host?.lowercased() ?? ""
        port = Self.effectivePort(endpoint)
    }

    func permits(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
            url.host?.lowercased() == host &&
            Self.effectivePort(url) == port
    }

    private static func effectivePort(_ url: URL) -> Int {
        url.port ?? 443
    }
}

private final class CalibrationCatalogRedirectDelegate: NSObject, URLSessionTaskDelegate,
    Sendable
{
    private let policy: CalibrationCatalogRedirectPolicy
    private let rejectedRedirect = Mutex(false)

    var didRejectRedirect: Bool {
        rejectedRedirect.withLock { $0 }
    }

    init(policy: CalibrationCatalogRedirectPolicy) {
        self.policy = policy
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let url = request.url, policy.permits(url) else {
            rejectedRedirect.withLock { $0 = true }
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

enum CalibrationCatalogRemoteResult: Equatable, Sendable {
    case success(CalibrationCatalogDocument)
    case failure(CalibrationCatalogRemoteFailure)
}

protocol CalibrationCatalogRemoteSource: Sendable {
    func fetch(
        region: String,
        locale: String
    ) async throws -> CalibrationCatalogRemoteResult
}

struct DefaultCalibrationCatalogRemoteSource: CalibrationCatalogRemoteSource {
    private let client: any CalibrationCatalogHTTPClient
    private let decoder: CalibrationCatalogDocumentDecoder

    init(
        client: any CalibrationCatalogHTTPClient,
        decoder: CalibrationCatalogDocumentDecoder = CalibrationCatalogDocumentDecoder()
    ) {
        self.client = client
        self.decoder = decoder
    }

    func fetch(
        region: String,
        locale: String
    ) async throws -> CalibrationCatalogRemoteResult {
        do {
            let response = try await client.get()
            switch response.statusCode {
                case 200:
                    guard response.contentType?.lowercased().contains("application/json") == true else {
                        return .failure(.invalid)
                    }
                    do {
                        return try .success(
                            decoder.decode(
                                response.data,
                                expectedRegion: region,
                                expectedLocale: locale
                            )
                        )
                    } catch CalibrationCatalogDocumentError.incompatible {
                        return .failure(.incompatible)
                    } catch {
                        return .failure(.invalid)
                    }
                case 404:
                    return .failure(.absent)
                default:
                    return .failure(.unavailable)
            }
        } catch CalibrationCatalogHTTPClientError.responseTooLarge {
            return .failure(.invalid)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .failure(.unavailable)
        }
    }
}

struct UnavailableCatalogRemoteSource: CalibrationCatalogRemoteSource {
    func fetch(
        region _: String,
        locale _: String
    ) async throws -> CalibrationCatalogRemoteResult {
        .failure(.unavailable)
    }
}
