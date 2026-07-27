import Foundation
import UIKit

final class ImageCache {
    private let cache = NSCache<NSURL, UIImage>()

    init(maxCostBytes: Int = 50 * 1024 * 1024) {
        cache.totalCostLimit = maxCostBytes
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(
            image,
            forKey: url as NSURL,
            cost: Self.estimatedCost(for: image)
        )
    }

    nonisolated static func estimatedCost(for image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }

        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)
        return pixelWidth * pixelHeight * 4
    }
}
