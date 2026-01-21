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
        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)
        let cost = max(0, pixelWidth * pixelHeight * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}
