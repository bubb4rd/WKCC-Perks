import UIKit

enum BusinessLogoImageProcessor {
    /// Downscales and compresses a picked image for logo upload (max edge 1024, JPEG ~0.8).
    static func jpegData(from image: UIImage, maxEdge: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        let scaled = scaledImage(image, maxEdge: maxEdge)
        return scaled.jpegData(compressionQuality: quality)
    }

    private static func scaledImage(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxEdge, longest > 0 else { return image }

        let scale = maxEdge / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
