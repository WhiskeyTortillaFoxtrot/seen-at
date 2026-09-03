import UIKit

enum PhotoCacheService {
    private nonisolated(unsafe) static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100
        c.totalCostLimit = 150 * 1024 * 1024
        return c
    }()

    private static func decodedCost(for image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        return Int(image.size.width * image.size.height * 4)
    }

    static func image(for sightingID: String, data: Data) -> UIImage? {
        let key = sightingID as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key, cost: decodedCost(for: image))
        return image
    }

    static func evict(sightingID: String) {
        cache.removeObject(forKey: sightingID as NSString)
    }

    static func clear() {
        cache.removeAllObjects()
    }
}
