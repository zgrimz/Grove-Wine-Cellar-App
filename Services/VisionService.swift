import UIKit
import Foundation

/// Reads a wine label photo into form fields, through a forced `record_wine_label` tool call (see
/// ``AIClient``) so the details come back as structured JSON from either provider.
class VisionService {
    static let shared = VisionService()

    func recognizeWineLabel(_ image: UIImage, provider: AIProvider, apiKey: String,
                            modelID: String) async throws -> RecognizedWineAttributes {
        guard !apiKey.isEmpty else { throw VisionError.notConfigured(provider) }
        guard !modelID.isEmpty else { throw VisionError.noModelSelected(provider) }

        // Calculate optimal dimensions based on aspect ratio
        let optimizedImage = image.optimizedForUpload()

        guard let imageData = optimizedImage.jpegData(compressionQuality: 0.7) else {
            throw VisionError.imageProcessingFailed
        }

        let input: [String: Any]
        do {
            input = try await AIClient.forcedToolInput(
                request(base64Image: imageData.base64EncodedString(), modelID: modelID),
                provider: provider, apiKey: apiKey)
        } catch AIClient.CallError.noToolCall {
            throw VisionError.noLabelFound
        } catch let error as AIClient.CallError {
            throw VisionError.aiFailure(error, provider)
        }

        guard let attributes = Self.attributes(from: input) else {
            throw VisionError.noLabelFound
        }
        return attributes
    }

    private func request(base64Image: String, modelID: String) -> AIToolRequest {
        AIToolRequest(
            modelID: modelID,
            maxTokens: 1024,
            systemPrompt: """
                You read wine labels. Given a photo of a bottle, call the record_wine_label tool \
                with the details you can see, inferring color, style and sweetness from the wine's \
                name, region and varietal where the label doesn't state them. Leave out anything \
                you can't read or reasonably infer.
                """,
            userText: "Record the details of this wine label.",
            image: AIImage(base64: base64Image, mediaType: "image/jpeg"),
            tool: AITool(
                name: "record_wine_label",
                description: "Record the details read from a wine label.",
                properties: [
                    "name": ["type": "string", "description": "The wine's name as printed."],
                    "color": ["type": "string", "enum": WineColor.allCases.map(\.rawValue)],
                    "style": ["type": "string", "enum": WineStyle.allCases.map(\.rawValue)],
                    "sweetness": ["type": "string", "enum": WineSweetness.allCases.map(\.rawValue)],
                    "producer": ["type": "string"],
                    "vintage": ["type": "integer", "description": "Four-digit year; omit for NV."],
                    "region": ["type": "string"],
                    "varietal": ["type": "string", "description": "Grape or blend."],
                ],
                required: ["name", "color", "style"]),
            timeout: 60)
    }

    /// Turn the tool input into form values, leniently: OpenAI treats enums as hints (see
    /// ``OpenAIWire``), so a near-miss like "rose" or "red" is matched rather than rejected, and an
    /// unrecognised color or style falls back to a default the user reviews in the form anyway.
    /// Nil only when there is no name — without one there is nothing to prefill.
    static func attributes(from input: [String: Any]) -> RecognizedWineAttributes? {
        guard let name = text(input["name"]) else { return nil }
        return RecognizedWineAttributes(
            name: name,
            color: match(input["color"], in: WineColor.allCases) ?? .other,
            style: match(input["style"], in: WineStyle.allCases) ?? .still,
            sweetness: match(input["sweetness"], in: WineSweetness.allCases).map { Set([$0]) } ?? Set(),
            producer: text(input["producer"]),
            vintage: year(input["vintage"]),
            region: text(input["region"]),
            varietal: text(input["varietal"]))
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }
        return string
    }

    private static func match<T: RawRepresentable>(_ value: Any?, in cases: [T]) -> T?
    where T.RawValue == String {
        guard let string = text(value) else { return nil }
        return cases.first {
            $0.rawValue.compare(string, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    /// The schema asks for an integer, but a string year ("2019") is common enough to accept.
    private static func year(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = text(value) { return Int(string) }
        return nil
    }

    enum VisionError: Error, LocalizedError {
        case notConfigured(AIProvider)
        case noModelSelected(AIProvider)
        case imageProcessingFailed
        case aiFailure(AIClient.CallError, AIProvider)
        case noLabelFound

        var errorDescription: String? {
            switch self {
            case .notConfigured(let provider):
                return "Add your \(provider.displayName) API key in Settings to scan wine labels."
            case .noModelSelected:
                return "Choose a label scanning model in Settings."
            case .imageProcessingFailed:
                return "Failed to process the image for analysis."
            case .aiFailure(let error, let provider):
                return error.summary(provider: provider)
            case .noLabelFound:
                return "Couldn't read a wine label in this photo."
            }
        }
    }
}

// Helper extension for image optimization
private extension UIImage {
    /// Resized to the long-edge limits both providers recommend for vision input, so a full-size
    /// camera photo isn't uploaded only to be downscaled on arrival.
    func optimizedForUpload() -> UIImage {
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
