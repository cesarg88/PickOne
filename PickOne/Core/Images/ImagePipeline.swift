import Foundation
import UIKit

final class ImagePipeline: ImageLoading {
    private let session: URLSession
    private let cache: ImageCache
    private let urlCache: URLCache

    init(
        cache: ImageCache = ImageCache(),
        urlCache: URLCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 0
        ),
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        let configuration = sessionConfiguration
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
        self.cache = cache
        self.urlCache = urlCache
    }

    func loadImage(from url: URL) async throws -> UIImage {
        if let cached = cache.image(for: url) {
            return cached
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cachedResponse = urlCache.cachedResponse(for: request) {
            try validate(response: cachedResponse.response)
            guard let image = UIImage(data: cachedResponse.data) else {
                throw ImagePipelineError.invalidImageData
            }
            cache.insert(image, for: url)
            return image
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        guard let image = UIImage(data: data) else {
            throw ImagePipelineError.invalidImageData
        }

        let cachedResponse = CachedURLResponse(response: response, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: request)
        cache.insert(image, for: url)
        return image
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImagePipelineError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ImagePipelineError.httpStatus(httpResponse.statusCode)
        }
        guard httpResponse.mimeType?.lowercased().hasPrefix("image/") == true else {
            throw ImagePipelineError.invalidContentType(httpResponse.mimeType)
        }
    }
}

enum ImagePipelineError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case invalidContentType(String?)
    case invalidImageData
}
