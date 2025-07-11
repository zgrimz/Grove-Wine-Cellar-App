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
        let vintage: Int?  // Made optional to handle null values
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
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-sonnet-20241022"
    
    init() {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let xml = FileManager.default.contents(atPath: path),
           let config = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] {
            self.apiKey = config["APIKey"] as? String ?? ""
        } else {
            self.apiKey = ""
            print("Warning: Failed to load API key from Config.plist")
        }
    }
    
    func getWineRecommendations(userQuery: String, inventory: [Wine], pairingType: PairingType = .food, preferredWineColor: WineColor? = nil) async throws -> WineRecommendation {
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
        let pairingPrompt = pairingType == .food ? 
            "Please recommend the best possible wine from the inventory to pair with the dish." :
            "Please recommend the best possible wine from the inventory for this occasion."
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": """
                            You are a professional sommelier. You will be provided with a wine inventory and a \(pairingContext). \(pairingPrompt) Return the response in the following exact JSON format:

                            {
                              "recommendedWine": {
                                "name": "Wine Name",
                                "producer": "Producer Name",
                                "vintage": YYYY
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

                            Note: betterPairingRecommendation should only be included if pairingConfidence is below 8.

                            Wine Inventory:
                            \(inventoryString)

                            \(pairingType == .food ? "Dish/Meal:" : "Occasion:") 
                            \(userQuery)
                            """
                        ]
                    ]
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(inventory)
        return String(data: data, encoding: .utf8) ?? "[]"
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
    
    enum SommelierError: Error {
        case apiError
        case noRecommendations
        case invalidResponseFormat
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