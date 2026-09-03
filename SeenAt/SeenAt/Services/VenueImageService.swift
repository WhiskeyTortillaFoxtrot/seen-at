import SwiftUI
import UIKit

enum VenueImageService {
    private nonisolated(unsafe) static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 50 * 1024 * 1024
        c.countLimit = 100
        return c
    }()

    private static func decodedCost(for image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        return Int(image.size.width * image.size.height * 4)
    }

    static func image(for venueKey: String) -> Image? {
        let normalized = normalize(venueKey)
        guard !normalized.isEmpty else { return nil }

        let cacheKey = normalized as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return Image(uiImage: cached)
        }

        for ext in ["png", "jpg", "jpeg"] {
            guard let url = Bundle.main.url(forResource: normalized, withExtension: ext),
                   let data = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: data)
            else { continue }
            cache.setObject(uiImage, forKey: cacheKey, cost: decodedCost(for: uiImage))
            return Image(uiImage: uiImage)
        }
        return nil
    }

    static func hasImage(for venueKey: String) -> Bool {
        image(for: venueKey) != nil
    }

    static func dailyImage(date: Date = .now, calendar: Calendar = .current) -> Image? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "daily-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return Image(uiImage: cached)
        }

        let images = (Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? [])
            .filter { $0.deletingPathExtension().lastPathComponent != "splash-screen-field" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !images.isEmpty else { return nil }

        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        guard let uiImage = UIImage(contentsOfFile: images[day % images.count].path) else { return nil }
        cache.setObject(uiImage, forKey: cacheKey, cost: decodedCost(for: uiImage))
        return Image(uiImage: uiImage)
    }

    static func normalize(_ key: String) -> String {
        let normalized = key.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "&", with: "and")

        return normalized
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: "-")
    }
}
