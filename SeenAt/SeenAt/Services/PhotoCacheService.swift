import UIKit

enum PhotoCacheService {
    private nonisolated(unsafe) static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100
        return c
    }()

    static func image(for sightingID: String, data: Data) -> UIImage? {
        let key = sightingID as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func evict(sightingID: String) {
        cache.removeObject(forKey: sightingID as NSString)
    }

    static func clear() {
        cache.removeAllObjects()
    }
}
