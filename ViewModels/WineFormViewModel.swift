import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
final class WineFormViewModel {
    var name = ""
    var color = WineColor.red
    var style = WineStyle.still
    var sweetness: Set<WineSweetness> = []
    var producer = ""
    var vintage = ""
    var region = ""
    var varietal = ""
    var notes = ""
    var image: UIImage? {
        didSet {
            // Any change to image is considered a modification
            imageWasModified = true
        }
    }
    var isProcessing = false
    var showingPhotoLibrary = false
    var showingCamera = false

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

    @ObservationIgnored private var imageWasModified = false
    @ObservationIgnored private var hasLoadedExistingImage = false
    @ObservationIgnored private let onSave: (Wine) throws -> Void
    @ObservationIgnored private let wine: Wine?
    @ObservationIgnored private let images = ImageStorageService.shared

    /// Kept cheap — no disk reads. SwiftUI evaluates `State(initialValue:)` on every re-render of
    /// the presenting view and discards all but the first instance; the photo loads in
    /// ``loadExistingImage()`` instead.
    init(wine: Wine? = nil, onSave: @escaping (Wine) throws -> Void) {
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
        }
    }

    /// Show the wine's current photo when editing. Loading it isn't a modification, and since an
    /// unmodified photo is never re-saved, a screen-sized preview is all that's needed.
    func loadExistingImage(maxPixelLength: CGFloat) async {
        guard !hasLoadedExistingImage, let imagePath = wine?.imagePath else { return }
        hasLoadedExistingImage = true
        let existing = await images.loadImage(fromPath: imagePath, maxPixelLength: maxPixelLength)
        // A photo picked while this was loading wins.
        guard !imageWasModified else { return }
        image = existing
        imageWasModified = false
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

    /// Save the wine, replacing its photo only once the new one is safely stored: write the new
    /// photo, persist, and only then delete the old one. A failure at any step leaves the wine
    /// pointing at a photo that exists.
    func save() throws {
        let oldPath = wine?.imagePath
        var imagePath = oldPath
        if imageWasModified {
            // nil when the user removed the photo
            imagePath = try image.map { try images.saveImage($0) }
        }

        let wine = Wine(
            id: self.wine?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
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

        do {
            try onSave(wine)
        } catch {
            // The wine still points at its old photo, so the new one is the orphan.
            if imageWasModified, let imagePath { try? images.deleteImage(atPath: imagePath) }
            throw error
        }

        if imageWasModified, let oldPath, oldPath != imagePath {
            try? images.deleteImage(atPath: oldPath)
        }
    }
}
