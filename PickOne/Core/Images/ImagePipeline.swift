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
            diskCapacity: 200 * 1024 * 1024
        )
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: configuration)
        self.cache = cache
        self.urlCache = urlCache
    }
    
    func loadImage(from url: URL) async throws -> UIImage {
        if let cached = cache.image(for: url) {
            return cached
        }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            cache.insert(image, for: url)
            return image
        }
        
        let (data, response) = try await session.data(for: request)
        let cachedResponse = CachedURLResponse(response: response, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: request)
        
        guard let image = UIImage(data: data) else {
            throw ImagePipelineError.invalidImageData
        }
        
        cache.insert(image, for: url)
        return image
    }
}

enum ImagePipelineError: Error {
    case invalidImageData
}
