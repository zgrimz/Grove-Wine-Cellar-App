import Foundation
import os
import Observation

@MainActor
@Observable
final class WineCellarQueryViewModel {
    enum PairingState {
        case idle
        case loading
        case result(WineRecommendation)
        case failed(String)
    }

    var foodInput = ""
    var pairingType: PairingType = .food
    var selectedWineColor: WineColor?
    private(set) var state: PairingState = .idle

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var canRequestPairing: Bool {
        !foodInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func getPairing(from wines: [Wine], settings: AISettings) async {
        guard canRequestPairing else { return }
        state = .loading

        do {
            guard settings.isEnabled else { throw SommelierService.SommelierError.aiDisabled }
            let recommendation = try await SommelierService.shared
                .getWineRecommendations(userQuery: foodInput, inventory: wines, pairingType: pairingType, preferredWineColor: selectedWineColor,
                                        provider: settings.provider, apiKey: settings.trimmedKey, modelID: settings.pairingModelID)
            state = .result(recommendation)
            foodInput = "" // Clear input after successful pairing
        } catch {
            Logger.ai.error("Pairing failed: \(error)")
            // Back on the input screen, with what the user typed still there to retry.
            state = .failed(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        foodInput = ""
        pairingType = .food
        selectedWineColor = nil
    }
}
