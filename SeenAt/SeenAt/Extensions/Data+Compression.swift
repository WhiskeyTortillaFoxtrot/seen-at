import UIKit
import os.log

extension Data {
    func downsampledImage(maxDimension: CGFloat, compressionQuality: CGFloat = 0.85) -> Data? {
        guard maxDimension > 0 else { return nil }
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCache: false
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: compressionQuality)
    }
}
