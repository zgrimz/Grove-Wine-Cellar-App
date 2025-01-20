import SwiftUI
import Combine

@MainActor
class WineListViewModel: ObservableObject {
    @Published var wines: [Wine] = []
    @Published var searchText = ""
    @Published var selectedType: WineType?
    @Published var showingSubtypesPicker = false
    
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
                (wine.producer?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesType = selectedType == nil || wine.type == selectedType
            
            return matchesSearch && matchesType
        }
    }
    
    func loadWines() async {
        do {
            wines = try repository.fetchWines()
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
    
    // Changed from updateWine to saveWine to match repository method
    func updateWine(_ wine: Wine) async {
        do {
            try repository.saveWine(wine)  // Changed from updateWine to saveWine
            await loadWines()
        } catch {
            print("Error updating wine: \(error)")
        }
    }
    
    // Changed from addWine to saveWine to match repository method
    func addWine(_ wine: Wine) async {
        do {
            try repository.saveWine(wine)  // Changed from addWine to saveWine
            await loadWines()
        } catch {
            print("Error adding wine: \(error)")
        }
    }
}
