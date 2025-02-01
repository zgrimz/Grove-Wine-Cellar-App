import Foundation

// Response model matching the required JSON structure
struct WineRecommendation: Codable {
    let recommendation: String
    let why: [String]          // Changed back to 'why' to match JSON
    let pairingConfidence: Int
    let alternateRecommendation: String?  // Changed to match JSON key
    
    // Computed property to format reasons as a string (keep this for convenience)
    var reasons: String {
        why.map { "• \($0)" }.joined(separator: "\n")
    }
    
    enum CodingKeys: String, CodingKey {
        case recommendation
        case why
        case pairingConfidence = "pairingConfidence"
        case alternateRecommendation = "alternateRecommendation"
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
    
    func getWineRecommendations(userQuery: String, inventory: [Wine]) async throws -> WineRecommendation {
        // Filter out archived wines
        let activeInventory = inventory.filter { !$0.isArchived }
        
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let inventoryString = try formatInventoryForPrompt(activeInventory)
        
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
                            You are a professional sommelier. You will be provided with a wine inventory and a dish/meal. Please recommend the best possible wine from the inventory to pair with the dish. Follow the instructions below exactly and return the final response in valid JSON format.

                            Recommendation: Name one wine from the provided inventory.
                            Why?: Provide a concise (2–3 bullet points) explanation of why this wine pairs well with the dish. Mention relevant wine attributes such as acidity, tannin, body, and flavor profile.
                            Pairing Confidence (1–10): Provide a numeric rating indicating how strongly you believe this wine complements the dish.
                            If Under 8: If the pairing confidence is below 8, explain briefly why the match isn't ideal and recommend a wine style or variety not found in the current inventory that might be a better match.

                            Wine Inventory:
                            \(inventoryString)

                            Dish/Meal:
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
        
        // Extract and parse the JSON response from Claude's text
        return try parseRecommendation(from: responseText)
    }
    
    private func formatInventoryForPrompt(_ inventory: [Wine]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(inventory)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
private func parseRecommendation(from text: String) throws -> WineRecommendation {
    // Print the full response for debugging
    print("Raw response from Claude:", text)
    
    // Find JSON content in the response
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