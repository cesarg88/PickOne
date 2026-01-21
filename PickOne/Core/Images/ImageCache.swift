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
        let cost = image.pngData()?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}
