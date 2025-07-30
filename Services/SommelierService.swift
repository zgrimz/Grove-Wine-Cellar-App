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

class SommelierService {
    static let shared = SommelierService()
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
    }
    
    private var model: String {
        UserDefaults.standard.string(forKey: "claudeModel") ?? "claude-sonnet-4-20250514"
    }
    
    func getWineRecommendations(userQuery: String, inventory: [Wine], pairingType: PairingType = .food, preferredWineColor: WineColor? = nil) async throws -> WineRecommendation {
        // Check if API key is configured
        guard !apiKey.isEmpty else {
            throw SommelierError.missingAPIKey
        }
        
        var filteredInventory = inventory.filter { !$0.isArchived }
        
        // Filter by wine color if specified
        if let preferredColor = preferredWineColor {
            filteredInventory = filteredInventory.filter { $0.color == preferredColor }
        }
        
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let inventoryString = try formatInventoryForPrompt(filteredInventory)
        let pairingContext = pairingType == .food ? "dish/meal" : "occasion"
        
let requestBody: [String: Any] = [
    "model": model,
    "max_tokens": 1024,
    "system": """
        You are a professional sommelier. When given a wine inventory and a \(pairingContext), recommend the best possible wine from that inventory.
        
        Return your response in the following exact JSON format:
        {
          "recommendedWine": {
            "name": "Wine Name",
            "producer": "Producer Name", 
            "vintage": "YYYY",
            "id": "WINE_ID_FROM_INVENTORY"
          },
          "whyThisPair": [
            "First reason with wine attributes (acidity, tannin, body, flavor)",
            "Second reason with complementary aspects"
          ],
          "pairingConfidence": N,
          "betterPairingRecommendation": {
            "wine": "Alternative wine style/variety", 
            "explanation": "Why this would be better"
          }
        }
        
        IMPORTANT: Use the exact "ID" value from the wine inventory for the "id" field in your response.
        IMPORTANT: For vintage, use the exact value from inventory (could be a year like "2019" or "NV" for non-vintage).
        Note: betterPairingRecommendation should only be included if pairingConfidence is below 8.
        """,
    "messages": [
        [
            "role": "user",
            "content": """
                Available Wine Inventory:
                \(inventoryString)
                
                \(pairingType == .food ? "Please recommend a wine to pair with this dish:" : "Please recommend a wine for this occasion:")
                \(userQuery)
                """
        ]
    ]
]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SommelierError.apiError
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let responseText = claudeResponse.content.first?.text else {
            throw SommelierError.noRecommendations
        }
        
        return try parseRecommendation(from: responseText)
    }
    
    private func formatInventoryForPrompt(_ inventory: [Wine]) throws -> String {
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
    
    private func parseRecommendation(from text: String) throws -> WineRecommendation {
        print("Raw response from Claude:", text)
        
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            print("Failed to find JSON markers in response")
            throw SommelierError.invalidResponseFormat
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        print("Extracted JSON string:", jsonString)
        
        do {
            let jsonData = jsonString.data(using: .utf8)!
            let recommendation = try JSONDecoder().decode(WineRecommendation.self, from: jsonData)
            return recommendation
        } catch {
            print("JSON Decoding error:", error)
            throw SommelierError.invalidResponseFormat
        }
    }
    
    enum SommelierError: Error, LocalizedError {
        case missingAPIKey
        case apiError
        case noRecommendations
        case invalidResponseFormat
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Please set your Claude API key in Settings to use AI features."
            case .apiError:
                return "Unable to connect to Claude API. Please check your API key and internet connection."
            case .noRecommendations:
                return "No wine recommendations were returned from the API."
            case .invalidResponseFormat:
                return "Received an unexpected response format from the API."
            }
        }
    }
    
    private struct ClaudeResponse: Codable {
        let content: [Content]
        let id: String
        let model: String
        let role: String
        
        struct Content: Codable {
            let text: String
            let type: String
        }
    }
}