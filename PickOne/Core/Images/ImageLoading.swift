import Foundation
import UIKit

protocol ImageLoading {
    func loadImage(from url: URL) async throws -> UIImage
}
