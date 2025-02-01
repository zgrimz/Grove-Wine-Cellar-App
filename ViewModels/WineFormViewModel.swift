import SwiftUI
import UIKit

@MainActor
class WineFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var type = WineType.red
    @Published var subTypes: Set<WineSubType> = []
    @Published var producer = ""
    @Published var vintage = ""
    @Published var region = ""
    @Published var varietal = ""
    @Published var image: UIImage?
    @Published var isProcessing = false
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    
    var isEditMode: Bool { wine != nil }
    
    private let onSave: (Wine) async -> Void
    private let wine: Wine?
    
    init(onSave: @escaping (Wine) async -> Void, wine: Wine? = nil) {
        self.onSave = onSave
        self.wine = wine
        
        if let wine = wine {
            self.name = wine.name
            self.type = wine.type
            self.subTypes = wine.subTypes
            self.producer = wine.producer ?? ""
            self.vintage = wine.vintage?.description ?? ""
            self.region = wine.region ?? ""
            self.varietal = wine.varietal ?? ""
            
            if let imagePath = wine.imagePath {
                self.image = ImageStorageService.shared.loadImage(fromPath: imagePath)
            }
        }
    }
    
    func processImage(_ image: UIImage) async throws -> RecognizedWineAttributes {
        isProcessing = true
        defer { isProcessing = false }
        
        return try await VisionService.shared.recognizeWineLabel(image)
    }
    
    func save() async throws {
        var imagePath = wine?.imagePath
        
        if let newImage = image {
            if let oldPath = imagePath {
                try ImageStorageService.shared.deleteImage(atPath: oldPath)
            }
            imagePath = try ImageStorageService.shared.saveImage(newImage, withName: name)
        }
        
        let vintageInt = Int(vintage)
        
        let wine = Wine(
            id: self.wine?.id ?? UUID(),
            name: name,
            type: type,
            subTypes: subTypes,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintageInt,
            region: region.isEmpty ? nil : region,
            varietal: varietal.isEmpty ? nil : varietal,
            imagePath: imagePath,
            dateAdded: self.wine?.dateAdded ?? Date(),
            isArchived: self.wine?.isArchived ?? false  // Preserve archived status
        )
        
        await onSave(wine)
    }
}
