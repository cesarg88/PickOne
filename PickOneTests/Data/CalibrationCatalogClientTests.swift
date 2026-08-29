import Foundation
@testable import PickOne
import Testing

@Suite("Calibration catalog remote source")
struct CalibrationCatalogRemoteSourceTests {
    @Test("valid JSON is admitted as one complete remote document")
    func validDocumentSucceeds() async throws {
        let expected = try CalibrationCatalogTestFixtures.document()
        let response = try response(data: expected.data)
        let sut = DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(outcome: .response(response))
        )

        let result = try await sut.fetch(region: "ES", locale: "es-ES")

        #expect(result == .success(expected))
    }

    @Test("remote outcomes remain exactly classified")
    func outcomesRemainClassified() async throws {
        let absent = try DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(
                outcome: .response(response(statusCode: 404))
            )
        )
        #expect(try await absent.fetch(region: "ES", locale: "es-ES") == .failure(.absent))

        let server = try DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(
                outcome: .response(response(statusCode: 503))
            )
        )
        #expect(try await server.fetch(region: "ES", locale: "es-ES") == .failure(.unavailable))

        let transport = DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(outcome: .error(.unavailable))
        )
        #expect(try await transport.fetch(region: "ES", locale: "es-ES") == .failure(.unavailable))

        let oversized = DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(outcome: .error(.responseTooLarge))
        )
        #expect(try await oversized.fetch(region: "ES", locale: "es-ES") == .failure(.invalid))
    }

    @Test("incompatible, invalid, and non-JSON responses are rejected distinctly")
    func documentFailuresRemainClassified() async throws {
        let original = try CalibrationCatalogTestFixtures.documentData()
        let text = try #require(String(data: original, encoding: .utf8))
        let incompatibleData = Data(
            text.replacingOccurrences(
                of: "\"schemaVersion\": 1",
                with: "\"schemaVersion\": 2"
            ).utf8
        )
        let incompatible = try DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(
                outcome: .response(response(data: incompatibleData))
            )
        )
        #expect(
            try await incompatible.fetch(region: "ES", locale: "es-ES") ==
                .failure(.incompatible)
        )

        let invalid = try DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(
                outcome: .response(response(data: Data("{}".utf8)))
            )
        )
        #expect(try await invalid.fetch(region: "ES", locale: "es-ES") == .failure(.invalid))

        let nonJSON = try DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(
                outcome: .response(
                    response(data: original, contentType: "text/plain")
                )
            )
        )
        #expect(try await nonJSON.fetch(region: "ES", locale: "es-ES") == .failure(.invalid))
    }

    @Test("caller cancellation is preserved")
    func cancellationIsPreserved() async {
        let sut = DefaultCalibrationCatalogRemoteSource(
            client: FixedCalibrationCatalogHTTPClient(outcome: .cancellation)
        )

        await #expect(throws: CancellationError.self) {
            try await sut.fetch(region: "ES", locale: "es-ES")
        }
    }

    private func response(
        data: Data = Data(),
        statusCode: Int = 200,
        contentType: String? = "application/json"
    ) throws -> CalibrationCatalogHTTPResponse {
        try CalibrationCatalogHTTPResponse(
            data: data,
            statusCode: statusCode,
            contentType: contentType,
            finalURL: #require(URL(string: "https://catalog.example/catalog.json"))
        )
    }
}

@Suite("HTTPS calibration catalog client", .serialized)
struct HTTPSCalibrationCatalogClientTests {
    @Test("only credential-free HTTPS endpoints are accepted")
    func endpointSecurity() throws {
        let insecure = try #require(URL(string: "http://catalog.example/catalog.json"))
        #expect(throws: CalibrationCatalogHTTPClientError.insecureEndpoint) {
            try HTTPSCalibrationCatalogClient(endpoint: insecure)
        }

        let credentialed = try #require(
            URL(string: "https://viewer:secret@catalog.example/catalog.json")
        )
        #expect(throws: CalibrationCatalogHTTPClientError.insecureEndpoint) {
            try HTTPSCalibrationCatalogClient(endpoint: credentialed)
        }
    }

    @Test("request is read-only and sends no credentials or viewer state")
    func requestIsReadOnly() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setSuccessResponse(data: Data("{}".utf8))
        let endpoint = try #require(URL(string: "https://catalog.example/catalog.json"))
        let sut = try HTTPSCalibrationCatalogClient(
            endpoint: endpoint,
            session: MockURLProtocol.createMockSession()
        )

        _ = try await sut.get()

        let request = try #require(MockURLProtocol.capturedRequests.last)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.url == endpoint)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test("streaming response enforces the byte limit")
    func responseLimit() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setSuccessResponse(data: Data(repeating: 1, count: 9))
        let endpoint = try #require(URL(string: "https://catalog.example/catalog.json"))
        let sut = try HTTPSCalibrationCatalogClient(
            endpoint: endpoint,
            session: MockURLProtocol.createMockSession(),
            maximumResponseBytes: 8
        )

        await #expect(throws: CalibrationCatalogHTTPClientError.responseTooLarge) {
            try await sut.get()
        }
    }

    @Test("a response redirected outside the configured trust boundary is rejected")
    func redirectTrustBoundary() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            guard let redirected = URL(string: "https://other.example/catalog.json"),
                  let response = HTTPURLResponse(
                      url: redirected,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: ["Content-Type": "application/json"]
                  )
            else {
                throw URLError(.badURL)
            }
            return (response, Data("{}".utf8))
        }
        let endpoint = try #require(URL(string: "https://catalog.example/catalog.json"))
        let sut = try HTTPSCalibrationCatalogClient(
            endpoint: endpoint,
            session: MockURLProtocol.createMockSession()
        )

        await #expect(throws: CalibrationCatalogHTTPClientError.untrustedRedirect) {
            try await sut.get()
        }
    }
}

private struct FixedCalibrationCatalogHTTPClient: CalibrationCatalogHTTPClient {
    enum Outcome: Sendable {
        case response(CalibrationCatalogHTTPResponse)
        case error(CalibrationCatalogHTTPClientError)
        case cancellation
    }

    let outcome: Outcome

    func get() async throws -> CalibrationCatalogHTTPResponse {
        switch outcome {
            case let .response(response): response
            case let .error(error): throw error
            case .cancellation: throw CancellationError()
        }
    }
}
