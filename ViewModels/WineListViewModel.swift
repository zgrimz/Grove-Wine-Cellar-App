import SwiftUI
import Combine
import Foundation

@MainActor
class WineListViewModel: ObservableObject {
    @Published var wines: [Wine] = []
    @Published var searchText = ""
    @Published var selectedColor: WineColor?
    @Published var selectedStyle: WineStyle?
    @Published var showArchived = false
    
    private let repository: WineRepository
    
    init(repository: WineRepository) {
        self.repository = repository
        Task {
            await loadWines()
        }
    }
    
    var filteredWines: [Wine] {
        wines.filter { wine in
            let matchesSearch = searchText.isEmpty || 
                wine.name.localizedCaseInsensitiveContains(searchText) ||
                wine.producer?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.region?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.varietal?.localizedCaseInsensitiveContains(searchText) == true ||
                wine.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                (wine.vintage != nil && String(wine.vintage!).contains(searchText))
            let matchesColor = selectedColor == nil || wine.color == selectedColor
            let matchesStyle = selectedStyle == nil || wine.style == selectedStyle
            let matchesArchiveState = wine.isArchived == showArchived
            return matchesSearch && matchesColor && matchesStyle && matchesArchiveState
        }
    }
    
    func loadWines() async {
        do {
            wines = try repository.fetchWines(includeArchived: true)
        } catch {
            print("Error loading wines: \(error)")
        }
    }
    
    func deleteWine(_ wine: Wine) {
        Task {
            do {
                try repository.deleteWine(id: wine.id)
                if let imagePath = wine.imagePath {
                    try ImageStorageService.shared.deleteImage(atPath: imagePath)
                }
                await loadWines()
            } catch {
                print("Error deleting wine: \(error)")
            }
        }
    }
    
    func updateWine(_ wine: Wine) async {
        do {
            try repository.saveWine(wine)
            await loadWines()
        } catch {
            print("Error updating wine: \(error)")
        }
    }
    
    func addWine(_ wine: Wine) async {
        do {
            try repository.saveWine(wine)
            await loadWines()
        } catch {
            print("Error adding wine: \(error)")
        }
    }
    
    func toggleArchived(_ wine: Wine) {
        Task {
            var updatedWine = wine
            updatedWine.isArchived.toggle()
            await updateWine(updatedWine)
        }
    }
}