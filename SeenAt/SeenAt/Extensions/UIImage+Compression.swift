import UIKit

extension UIImage {
    func downsampled(maxDimension: CGFloat, compressionQuality: CGFloat = 0.85) -> Data? {
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        guard scale < 1.0 else {
            return jpegData(compressionQuality: compressionQuality)
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}
