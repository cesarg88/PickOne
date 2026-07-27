import Foundation
import Testing
import UIKit
@testable import PickOne

@Suite("ImagePipeline Tests", .serialized)
struct ImagePipelineTests {
    @Test("rejects unsuccessful HTTP responses")
    func rejectsHTTPFailure() async {
        let sut = makeSUT(
            statusCode: 404,
            contentType: "image/png",
            data: validPNGData
        )

        await #expect(throws: ImagePipelineError.httpStatus(404)) {
            _ = try await sut.loadImage(from: URL(string: "https://example.com/a.png")!)
        }
    }

    @Test("rejects non-image content")
    func rejectsNonImageContent() async {
        let sut = makeSUT(
            statusCode: 200,
            contentType: "text/html",
            data: Data("<html></html>".utf8)
        )

        await #expect(
            throws: ImagePipelineError.invalidContentType("text/html")
        ) {
            _ = try await sut.loadImage(from: URL(string: "https://example.com/a.png")!)
        }
    }

    @Test("decodes valid image responses")
    func decodesValidImage() async throws {
        let sut = makeSUT(
            statusCode: 200,
            contentType: "image/png",
            data: validPNGData
        )

        let image = try await sut.loadImage(
            from: URL(string: "https://example.com/a.png")!
        )

        #expect(image.size.width > 0)
        #expect(ImageCache.estimatedCost(for: image) > 0)
    }

    private func makeSUT(
        statusCode: Int,
        contentType: String,
        data: Data
    ) -> ImagePipeline {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": contentType]
            )!
            return (response, data)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return ImagePipeline(
            urlCache: URLCache(
                memoryCapacity: 1024 * 1024,
                diskCapacity: 0
            ),
            sessionConfiguration: configuration
        )
    }

    private var validPNGData: Data {
        Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nWQAAAAASUVORK5CYII="
        )!
    }
}
