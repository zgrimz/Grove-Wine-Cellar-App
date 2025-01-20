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
    
    func saveImage(_ image: UIImage, withName name: String) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw ImageError.compressionFailed
        }
        
        let fileName = "\(name)_\(UUID().uuidString).jpg"
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
