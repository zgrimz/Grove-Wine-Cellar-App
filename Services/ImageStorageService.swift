import ImageIO
import UIKit

class ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default

    private var imagesDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("wine_images")
    }

    private init() {
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    /// Writes the photo and returns its file name. The name is a bare UUID: building it from the
    /// wine's name broke on a "/" (it reads as a subdirectory, so the write fails). Older photos
    /// saved under the previous scheme keep their stored names and still load.
    ///
    /// Stored at most 2048 px on the long edge — plenty for any screen in the app, and a fraction
    /// of a full-resolution camera photo.
    func saveImage(_ image: UIImage) throws -> String {
        guard let data = image.scaledDown(toMaxPixelLength: 2048).jpegData(compressionQuality: 0.7) else {
            throw ImageError.compressionFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL)
        return fileName
    }

    /// The photo decoded at no more than `maxPixelLength` on its long edge, off the main thread.
    ///
    /// ImageIO decodes straight to the requested size, so an 80-point list row no longer inflates a
    /// full-resolution photo (tens of MB) on the main thread to show it.
    func loadImage(fromPath path: String, maxPixelLength: CGFloat) async -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(path)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // apply EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelLength,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    func deleteImage(atPath path: String) throws {
        let fileURL = imagesDirectory.appendingPathComponent(path)
        try fileManager.removeItem(at: fileURL)
    }

    enum ImageError: Error {
        case compressionFailed
    }
}

extension UIImage {
    /// A copy whose longer side is at most `maxPixelLength` pixels, with the orientation baked in.
    /// Never upscales.
    ///
    /// Renders at scale 1 on purpose: `UIGraphicsImageRenderer`'s default format uses the
    /// screen's scale, so a "1568-point" image would come out at 4704 pixels on a 3x iPhone.
    func scaledDown(toMaxPixelLength maxPixelLength: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let factor = min(1, maxPixelLength / max(pixelWidth, pixelHeight))
        let target = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
