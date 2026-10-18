import Foundation

enum PairingType {
    case food
    case occasion
}

// Response model matching the required JSON structure
struct WineRecommendation: Codable {
    struct RecommendedWine: Codable {
        let name: String
        let producer: String
        let vintage: String?  // Changed to String to handle "NV", years, etc.
        let id: String  // Wine ID for precise matching
    }
    
    struct BetterPairing: Codable {
        let wine: String
        let explanation: String
    }
    
    let recommendedWine: RecommendedWine
    let whyThisPair: [String]
    let pairingConfidence: Int
    let betterPairingRecommendation: BetterPairing?
    
    // Updated computed property to handle optional vintage
    var recommendation: String {
        if let vintage = recommendedWine.vintage {
            return "\(recommendedWine.name) \(vintage)"
        }
        return recommendedWine.name
    }
    
    var why: [String] {
        whyThisPair
    }
    
    var alternateRecommendation: String? {
        betterPairingRecommendation.map { "\($0.wine): \($0.explanation)" }
    }
    
    var reasons: String {
        why.map { "• \($0)" }.joined(separator: "\n")
    }
}

/// Picks the bottle from the user's cellar for a dish or occasion, through a forced
/// `recommend_wine` tool call (see ``AIClient``) so the answer comes back as structured JSON from
/// either provider.
class SommelierService {
    static let shared = SommelierService()

    func getWineRecommendations(userQuery: String, inventory: [Wine], pairingType: PairingType = .food,
                                preferredWineColor: WineColor? = nil, provider: AIProvider,
                                apiKey: String, modelID: String) async throws -> WineRecommendation {
        guard !apiKey.isEmpty else { throw SommelierError.notConfigured(provider) }
        guard !modelID.isEmpty else { throw SommelierError.noModelSelected(provider) }

        var filteredInventory = inventory.filter { !$0.isArchived }

        // Filter by wine color if specified
        if let preferredColor = preferredWineColor {
            filteredInventory = filteredInventory.filter { $0.color == preferredColor }
        }

        // With nothing to choose from, the model would only invent a bottle.
        guard !filteredInventory.isEmpty else { throw SommelierError.emptyCellar }

        let input: [String: Any]
        do {
            input = try await AIClient.forcedToolInput(
                request(userQuery: userQuery, inventory: filteredInventory, pairingType: pairingType,
                        modelID: modelID),
                provider: provider, apiKey: apiKey)
        } catch AIClient.CallError.noToolCall {
            throw SommelierError.invalidResponseFormat
        } catch let error as AIClient.CallError {
            throw SommelierError.aiFailure(error, provider)
        }

        guard let recommendation = Self.recommendation(from: input) else {
            throw SommelierError.invalidResponseFormat
        }
        return recommendation
    }

    private func request(userQuery: String, inventory: [Wine], pairingType: PairingType,
                         modelID: String) -> AIToolRequest {
        let pairingContext = pairingType == .food ? "dish/meal" : "occasion"
        return AIToolRequest(
            modelID: modelID,
            maxTokens: 1024,
            systemPrompt: """
                You are a professional sommelier. When given a wine inventory and a \(pairingContext), \
                choose the best possible wine from that inventory and call the recommend_wine tool.

                Use the exact "ID" value from the inventory for the wine's id, and its vintage \
                exactly as listed (a year like "2019", or "NV" for non-vintage). Include \
                betterPairingRecommendation only if pairingConfidence is below 8.
                """,
            userText: """
                Available Wine Inventory:
                \(formatInventoryForPrompt(inventory))

                \(pairingType == .food ? "Please recommend a wine to pair with this dish:" : "Please recommend a wine for this occasion:")
                \(userQuery)
                """,
            image: nil,
            tool: AITool(
                name: "recommend_wine",
                description: "Recommend one wine from the inventory.",
                properties: [
                    "recommendedWine": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string", "description": "The wine's exact ID from the inventory."],
                            "name": ["type": "string"],
                            "producer": ["type": "string"],
                            "vintage": ["type": "string", "description": "Exactly as in the inventory."],
                        ],
                        "required": ["id", "name", "producer"],
                    ],
                    "whyThisPair": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Two or three reasons, citing the wine's acidity, tannin, body or flavor and how they complement the pairing.",
                    ],
                    "pairingConfidence": ["type": "integer", "minimum": 1, "maximum": 10],
                    "betterPairingRecommendation": [
                        "type": "object",
                        "description": "Only when pairingConfidence is below 8: a wine style or variety, not necessarily in the inventory, that would pair better.",
                        "properties": [
                            "wine": ["type": "string"],
                            "explanation": ["type": "string"],
                        ],
                        "required": ["wine", "explanation"],
                    ],
                ],
                required: ["recommendedWine", "whyThisPair", "pairingConfidence"]),
            timeout: 60)
    }

    private func formatInventoryForPrompt(_ inventory: [Wine]) -> String {
        let inventoryItems = inventory.map { wine in
            var item = "ID: \(wine.id.uuidString)\n"
            item += "Name: \(wine.name)\n"
            if let producer = wine.producer {
                item += "Producer: \(producer)\n"
            }
            if let vintage = wine.vintage {
                item += "Vintage: \(vintage)\n"
            }
            item += "Color: \(wine.color.rawValue)\n"
            item += "Style: \(wine.style.rawValue)\n"
            if let region = wine.region {
                item += "Region: \(region)\n"
            }
            if let varietal = wine.varietal {
                item += "Varietal: \(varietal)\n"
            }
            if let notes = wine.notes, !notes.isEmpty {
                item += "Notes: \(notes)\n"
            }
            return item
        }

        return inventoryItems.joined(separator: "\n---\n")
    }

    /// Decode the tool input into a ``WineRecommendation``. The schema asks for a string vintage,
    /// but a bare year arriving as a number — or a producer left out for a wine that has none —
    /// is common enough to accept rather than fail the whole pairing over.
    static func recommendation(from input: [String: Any]) -> WineRecommendation? {
        var input = input
        if var wine = input["recommendedWine"] as? [String: Any] {
            if let vintage = wine["vintage"] as? NSNumber { wine["vintage"] = vintage.stringValue }
            if wine["producer"] == nil { wine["producer"] = "" }
            input["recommendedWine"] = wine
        }
        guard JSONSerialization.isValidJSONObject(input),
              let data = try? JSONSerialization.data(withJSONObject: input) else { return nil }
        return try? JSONDecoder().decode(WineRecommendation.self, from: data)
    }

    enum SommelierError: Error, LocalizedError {
        case aiDisabled
        case notConfigured(AIProvider)
        case noModelSelected(AIProvider)
        case emptyCellar
        case aiFailure(AIClient.CallError, AIProvider)
        case invalidResponseFormat

        var errorDescription: String? {
            switch self {
            case .aiDisabled:
                return "Turn on AI features in Settings to get pairing recommendations."
            case .notConfigured(let provider):
                return "Add your \(provider.displayName) API key in Settings to get pairing recommendations."
            case .noModelSelected:
                return "Choose a pairing model in Settings."
            case .emptyCellar:
                return "There are no wines in your cellar to choose from. Add a wine, or pick a different color."
            case .aiFailure(let error, let provider):
                return error.summary(provider: provider)
            case .invalidResponseFormat:
                return "Received an unexpected response format from the API."
            }
        }
    }
}
