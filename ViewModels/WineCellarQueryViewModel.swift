import Foundation
import SwiftUI

@MainActor
class WineCellarQueryViewModel: ObservableObject {
    @Published var foodInput = ""
    @Published var currentPairing: ChatMessage?
    @Published var isLoading = false
    
    private let repository: WineRepository
    
    init(repository: WineRepository) {
        self.repository = repository
    }
    
    func getPairing() async {
        guard !foodInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let inventory = try repository.fetchWines()
            let recommendation = try await SommelierService.shared
                .getWineRecommendations(userQuery: foodInput, inventory: inventory)
            
            currentPairing = ChatMessage(
                content: recommendation,
                isUser: false,
                timestamp: Date()
            )
            foodInput = "" // Clear input after successful pairing
        } catch {
            currentPairing = ChatMessage(
                content: "Sorry, I couldn't find a wine pairing. Please try again.",
                isUser: false,
                timestamp: Date()
            )
        }
    }
    
    func reset() {
        currentPairing = nil
        foodInput = ""
    }
}