import SwiftUI

enum VenueImageService {
    static func image(for venueKey: String) -> Image? {
        let normalized = normalize(venueKey)
        for ext in ["png", "jpg", "jpeg"] {
            guard let url = Bundle.main.url(forResource: normalized, withExtension: ext, subdirectory: "VenueImages"),
                  let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data)
            else { continue }
            return Image(uiImage: uiImage)
        }
        return nil
    }

    static func hasImage(for venueKey: String) -> Bool {
        image(for: venueKey) != nil
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
