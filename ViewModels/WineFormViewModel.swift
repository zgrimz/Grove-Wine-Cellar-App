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

    /// The vintage as a year, or nil when the field is empty or isn't a plausible one.
    var vintageYear: Int? {
        guard let year = Int(vintage.trimmingCharacters(in: .whitespaces)) else { return nil }
        let nextYear = Calendar.current.component(.year, from: Date()) + 1
        return (1000...nextYear).contains(year) ? year : nil
    }

    /// Empty is fine (non-vintage); anything else has to be a real year. The store keeps vintages
    /// as Int16, so an unchecked "99999" would have crashed the save.
    var isVintageValid: Bool {
        vintage.trimmingCharacters(in: .whitespaces).isEmpty || vintageYear != nil
    }

    /// Save waits out a running scan, which would otherwise overwrite fields after the fact.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isVintageValid && !isProcessing
    }
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
    
    /// Read the label in a newly picked photo into the form.
    func scanLabel(_ image: UIImage, settings: AISettings) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        apply(try await VisionService.shared.recognizeWineLabel(image, provider: settings.provider,
                                                                apiKey: settings.trimmedKey,
                                                                modelID: settings.labelScanningModelID))
    }

    /// Fill in what the scan read and leave everything else alone, so a detail the label doesn't
    /// show never blanks one the user already entered.
    private func apply(_ attributes: RecognizedWineAttributes) {
        name = attributes.name
        if let color = attributes.color { self.color = color }
        if let style = attributes.style { self.style = style }
        if let sweetness = attributes.sweetness { self.sweetness = sweetness }
        if let producer = attributes.producer { self.producer = producer }
        if let vintage = attributes.vintage { self.vintage = String(vintage) }
        if let region = attributes.region { self.region = region }
        if let varietal = attributes.varietal { self.varietal = varietal }
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
                imagePath = try ImageStorageService.shared.saveImage(newImage)
            } else {
                // User removed the image
                imagePath = nil
            }
        }

        let wine = Wine(
            id: self.wine?.id ?? UUID(),
            name: name,
            color: color,
            style: style,
            sweetness: sweetness,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintageYear,
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