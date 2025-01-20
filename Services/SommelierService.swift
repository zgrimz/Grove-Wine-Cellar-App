import Foundation

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
    
    func getWineRecommendations(userQuery: String, inventory: [Wine]) async throws -> String {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let inventoryJSON = try JSONEncoder().encode(inventory)
        let inventoryString = String(data: inventoryJSON, encoding: .utf8) ?? "[]"
        
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
                            Given this wine inventory in JSON format:
                            \(inventoryString)
                            
                            User question: \(userQuery)
                            
                            Please provide wine recommendations from this inventory only. Focus on food pairings and serving suggestions.
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
        return claudeResponse.content.first?.text ?? "No recommendations available."
    }
    
    enum SommelierError: Error {
        case apiError
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