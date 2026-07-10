import SwiftUI

struct StadiumPhotoService {
    static func image(for venueName: String) -> Image? {
        VenueImageService.image(for: venueName)
    }
}
