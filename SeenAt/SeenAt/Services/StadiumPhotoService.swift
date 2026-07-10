import SwiftUI

struct StadiumPhotoService {
    static func image(for venueName: String) -> Image? {
        let fileName = venueName.replacingOccurrences(of: " ", with: "_")
        for ext in ["jpg", "jpeg", "png"] {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: ext, subdirectory: "StadiumPhotos"),
                  let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data)
            else { continue }
            return Image(uiImage: uiImage)
        }
        return nil
    }
}
