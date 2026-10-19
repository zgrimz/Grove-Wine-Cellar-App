import Foundation
import os
import Observation

/// The app's one in-memory copy of the cellar, shared by every screen through the environment.
///
/// Every write goes through here and reloads `wines`, so the list, the detail screen and the
/// pairing result all see a change the moment it's made — wherever it was made. Before this, the
/// list and the pairing screen each held their own copy, and a wine edited or deleted from one
/// stayed stale in the other.
@MainActor
@Observable
final class WineStore {
    /// Every wine, archived ones included, newest first.
    private(set) var wines: [Wine] = []

    @ObservationIgnored private let repository: WineRepository
    @ObservationIgnored private let images = ImageStorageService.shared

    init(repository: WineRepository) {
        self.repository = repository
    }

    func wine(id: UUID) -> Wine? {
        wines.first { $0.id == id }
    }

    func load() {
        do {
            wines = try repository.fetchWines()
        } catch {
            Logger.data.error("Couldn't load wines: \(error)")
        }
    }

    func add(_ wine: Wine) throws {
        try repository.insert(wine)
        load()
    }

    func update(_ wine: Wine) throws {
        try repository.update(wine)
        load()
    }

    func setArchived(_ isArchived: Bool, for wine: Wine) throws {
        var updated = wine
        updated.isArchived = isArchived
        try update(updated)
    }

    /// Deletes the wine and its photo. The photo goes second: a leftover file is harmless, but a
    /// wine pointing at a deleted photo is not.
    func delete(_ wine: Wine) throws {
        try repository.delete(id: wine.id)
        load()
        if let imagePath = wine.imagePath {
            do {
                try images.deleteImage(atPath: imagePath)
            } catch {
                Logger.data.error("Couldn't delete the photo of a deleted wine: \(error)")
            }
        }
    }
}
