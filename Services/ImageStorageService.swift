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
    func saveImage(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw ImageError.compressionFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL)
        return fileName
    }

    func loadImage(fromPath path: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
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
