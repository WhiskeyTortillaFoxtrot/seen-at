import Foundation
import UIKit

/// Photo storage quality tiers for newly saved sighting photos. Standard
/// preserves the historical behavior (1200px, 0.85 JPEG). Applies only at
/// save time; already-stored photos are never re-encoded.
enum PhotoQuality: String, Sendable, CaseIterable, Hashable {
    case low
    case standard
    case high

    var maxDimension: CGFloat {
        switch self {
        case .low: 800
        case .standard: 1200
        case .high: 2400
        }
    }

    var compressionQuality: CGFloat {
        switch self {
        case .low: 0.7
        case .standard: 0.85
        case .high: 0.95
        }
    }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .standard: "Standard"
        case .high: "High"
        }
    }

    static var current: PhotoQuality {
        guard let raw = UserDefaults.standard.string(forKey: AppPreferences.photoQualityKey) else {
            return .standard
        }
        return PhotoQuality(rawValue: raw) ?? .standard
    }
}

enum PhotoCompression {
    nonisolated static func compressPhoto(_ data: Data, quality: PhotoQuality = .current) -> Data? {
        data.downsampledImage(maxDimension: quality.maxDimension, compressionQuality: quality.compressionQuality)
    }
}
