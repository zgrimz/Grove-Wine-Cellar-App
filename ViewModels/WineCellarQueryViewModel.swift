import Foundation
import SwiftUI

@MainActor
class WineCellarQueryViewModel: ObservableObject {
    @Published var foodInput = ""
    @Published var currentPairing: ChatMessage?
    @Published var currentRecommendation: WineRecommendation?
    @Published var matchedWine: Wine?
    @Published var isLoading = false
    @Published var pairingType: PairingType = .food
    @Published var selectedWineColor: WineColor?
    
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
                .getWineRecommendations(userQuery: foodInput, inventory: inventory, pairingType: pairingType, preferredWineColor: selectedWineColor)
            
            // Store the structured recommendation
            currentRecommendation = recommendation
            
            // Find the matching wine in inventory
            matchedWine = inventory.first { wine in
                wine.name.localizedCaseInsensitiveContains(recommendation.recommendedWine.name) &&
                wine.producer?.localizedCaseInsensitiveContains(recommendation.recommendedWine.producer) == true
            }
            
            // Format the recommendation into a readable string for fallback
            let formattedContent = """
                Recommended Wine: \(recommendation.recommendation)

                Why This Pairing Works:
                \(recommendation.reasons)

                Pairing Confidence: \(recommendation.pairingConfidence)/10

                \(recommendation.alternateRecommendation.map { "Alternative Suggestion: \($0)" } ?? "")
                """
            
            currentPairing = ChatMessage(
                content: formattedContent,
                isUser: false,
                timestamp: Date()
            )
            foodInput = "" // Clear input after successful pairing
        } catch {
            print("Error getting wine pairing:", error)
            currentPairing = ChatMessage(
                content: "Error: \(error.localizedDescription)",
                isUser: false,
                timestamp: Date()
            )
        }
    }
    
    func reset() {
        currentPairing = nil
        currentRecommendation = nil
        matchedWine = nil
        foodInput = ""
        pairingType = .food
        selectedWineColor = nil
    }
}