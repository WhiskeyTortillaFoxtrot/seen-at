import SwiftUI

enum VenueImageService {
    static func image(for venueKey: String) -> Image? {
        let normalized = normalize(venueKey)
        guard let url = Bundle.main.url(forResource: normalized, withExtension: "png", subdirectory: "VenueImages"),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data)
        else { return nil }
        return Image(uiImage: uiImage)
    }

    static func hasImage(for venueKey: String) -> Bool {
        let normalized = normalize(venueKey)
        return Bundle.main.url(forResource: normalized, withExtension: "png", subdirectory: "VenueImages") != nil
    }

    private static func normalize(_ key: String) -> String {
        key.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: " ", with: "-")
    }
}
