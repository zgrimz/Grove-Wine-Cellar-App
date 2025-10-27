import SwiftUI
import UIKit
import Foundation

@MainActor
class WineFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var color = WineColor.red
    @Published var style = WineStyle.still
    @Published var sweetness: Set<WineSweetness> = []
    @Published var producer = ""
    @Published var vintage = ""
    @Published var region = ""
    @Published var varietal = ""
    @Published var notes = ""
    @Published var image: UIImage? {
        didSet {
            // Any change to image is considered a modification
            imageWasModified = true
        }
    }
    @Published var isProcessing = false
    @Published var showingImagePicker = false
    @Published var showingCamera = false

    var isEditMode: Bool { wine != nil }
    private var imageWasModified = false

    private let onSave: (Wine) async -> Void
    private let wine: Wine?

    init(onSave: @escaping (Wine) async -> Void, wine: Wine? = nil) {
        self.onSave = onSave
        self.wine = wine

        if let wine = wine {
            self.name = wine.name
            self.color = wine.color
            self.style = wine.style
            self.sweetness = wine.sweetness
            self.producer = wine.producer ?? ""
            self.vintage = wine.vintage?.description ?? ""
            self.region = wine.region ?? ""
            self.varietal = wine.varietal ?? ""
            self.notes = wine.notes ?? ""

            if let imagePath = wine.imagePath {
                self.image = ImageStorageService.shared.loadImage(fromPath: imagePath)
            }

            // Reset flag after loading existing data - loading isn't a modification
            self.imageWasModified = false
        }
    }
    
    func processImage(_ image: UIImage) async throws -> RecognizedWineAttributes {
        isProcessing = true
        defer { isProcessing = false }
        
        return try await VisionService.shared.recognizeWineLabel(image)
    }
    
    func save() async throws {
        var imagePath = wine?.imagePath

        // Only update image storage if the image was actually modified
        if imageWasModified {
            // Delete old image if it exists
            if let oldPath = imagePath {
                try? ImageStorageService.shared.deleteImage(atPath: oldPath)
            }

            // Save new image if one is set
            if let newImage = image {
                imagePath = try ImageStorageService.shared.saveImage(newImage, withName: name)
            } else {
                // User removed the image
                imagePath = nil
            }
        }

        let vintageInt = Int(vintage)

        let wine = Wine(
            id: self.wine?.id ?? UUID(),
            name: name,
            color: color,
            style: style,
            sweetness: sweetness,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintageInt,
            region: region.isEmpty ? nil : region,
            varietal: varietal.isEmpty ? nil : varietal,
            notes: notes.isEmpty ? nil : notes,
            imagePath: imagePath,
            dateAdded: self.wine?.dateAdded ?? Date(),
            isArchived: self.wine?.isArchived ?? false
        )

        await onSave(wine)
    }
}