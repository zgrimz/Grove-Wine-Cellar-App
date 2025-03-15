import UIKit
import Foundation

class VisionService {
    static let shared = VisionService()
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-sonnet-20241022"
    
    init() {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = config["APIKey"] as? String {
            self.apiKey = key
        } else {
            fatalError("API Key not found in Config.plist")
        }
    }
    
    // Intermediate struct to match the API response format
    private struct APIWineResponse: Codable {
        let name: String
        let color: WineColor
        let style: WineStyle
        let sweetness: WineSweetness?
        let producer: String?
        let vintage: Int?
        let region: String?
        let varietal: String?
    }

    func recognizeWineLabel(_ image: UIImage) async throws -> RecognizedWineAttributes {
        // Calculate optimal dimensions based on aspect ratio
        let optimizedImage = image.optimizedForClaude()
        
        guard let imageData = optimizedImage.jpegData(compressionQuality: 0.7) else {
            throw VisionError.imageProcessingFailed
        }

        // Encode the image as base64
        let base64Image = imageData.base64EncodedString()
        print("Base64 image encoded successfully.")

        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        // Construct the API request body
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": """
                            Return a JSON object with ONLY the following fields describing the wine label, inferring details where possible:
                            {
                                \"name\": \"string\",
                                \"color\": \"Red|White|Rosé|Orange|Other\",
                                \"style\": \"Still|Sparkling|Fortified\",
                                \"sweetness\": \"Dry|Off-Dry|Sweet|Dessert-Sweet|null\",
                                \"producer\": \"string|null\",
                                \"vintage\": number|null,
                                \"region\": \"string|null\",
                                \"varietal\": \"string|null\"
                            }
                            Do not include any additional text, description, or explanation - only return valid JSON.
                            """
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        print("Request body created successfully.")

        // Perform the API request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                throw VisionError.apiError("Status code: \(httpResponse.statusCode), Response: \(responseString)")
            }
            throw VisionError.invalidResponse
        }

        print("API response received successfully.")

        // Parse Claude response
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        guard let content = claudeResponse.content.first?.text else {
            throw VisionError.parsingFailed
        }

        print("Response content extracted: \(content)")

        // Convert the content string to data for JSON parsing
        guard let jsonData = content.data(using: .utf8) else {
            throw VisionError.parsingFailed
        }

        // First parse to our intermediate APIWineResponse
        let apiResponse = try JSONDecoder().decode(APIWineResponse.self, from: jsonData)
        
        // Transform to our RecognizedWineAttributes model
        let attributes = RecognizedWineAttributes(
            name: apiResponse.name,
            color: apiResponse.color,
            style: apiResponse.style,
            sweetness: apiResponse.sweetness.map { Set([$0]) } ?? Set(),
            producer: apiResponse.producer,
            vintage: apiResponse.vintage,
            region: apiResponse.region,
            varietal: apiResponse.varietal
        )
        
        print("Extracted wine attributes: \(attributes)")
        
        return attributes
    }

    enum VisionError: Error {
        case imageProcessingFailed
        case parsingFailed
        case apiError(String)
        case networkError(Error)
        case invalidResponse
    }
}

// Helper structures for Claude API response
private extension VisionService {
    struct ClaudeResponse: Codable {
        let content: [Content]
        let id: String
        let model: String
        let role: String
        let stopReason: String
        let stopSequence: String?
        let type: String
        let usage: Usage
        
        struct Content: Codable {
            let text: String
            let type: String
        }
        
        struct Usage: Codable {
            let inputTokens: Int
            let outputTokens: Int
            
            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case content
            case id
            case model
            case role
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
            case type
            case usage
        }
    }
}

// Helper extension for image optimization
private extension UIImage {
    func optimizedForClaude() -> UIImage {
        let aspectRatio = size.width / size.height
        var targetSize: CGSize
        
        // Determine optimal dimensions based on aspect ratio
        switch aspectRatio {
        case 0.9...1.1: // ~1:1
            targetSize = CGSize(width: 1092, height: 1092)
        case 0.7...0.8: // ~3:4
            targetSize = CGSize(width: 951, height: 1268)
        case 0.6...0.7: // ~2:3
            targetSize = CGSize(width: 896, height: 1344)
        case 0.5...0.6: // ~9:16
            targetSize = CGSize(width: 819, height: 1456)
        case 0.4...0.5: // ~1:2
            targetSize = CGSize(width: 784, height: 1568)
        default:
            // For other aspect ratios, maintain aspect ratio with max dimension of 1568
            if aspectRatio > 1 {
                let width = min(1568.0, size.width)
                targetSize = CGSize(width: width, height: width / aspectRatio)
            } else {
                let height = min(1568.0, size.height)
                targetSize = CGSize(width: height * aspectRatio, height: height)
            }
        }
        
        return autoreleasepool {
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }
}