import Foundation

/// Anthropic's Messages API, with a forced `tool_choice` so the answer arrives as validated JSON.
struct AnthropicWire: AIWireFormat {
    private let base = "https://api.anthropic.com/v1"

    func endpoint(modelID: String) throws -> URL {
        guard let url = URL(string: "\(base)/messages") else {
            throw AIClient.CallError.transport("Couldn't build the Anthropic endpoint URL.")
        }
        return url
    }

    func headers(apiKey: String) -> [String: String] {
        ["Content-Type": "application/json",
         "x-api-key": apiKey,
         "anthropic-version": "2023-06-01"]
    }

    func requestBody(for request: AIToolRequest) -> [String: Any] {
        var content: [[String: Any]] = []
        // Image before text, as the label scanner frames it.
        if let image = request.image {
            content.append(["type": "image",
                            "source": ["type": "base64",
                                       "media_type": image.mediaType,
                                       "data": image.base64]])
        }
        content.append(["type": "text", "text": request.userText])

        return [
            "model": request.modelID,
            "max_tokens": scaledMaxTokens(request.maxTokens),
            "system": request.systemPrompt,
            "messages": [["role": "user", "content": content]],
            "tools": [["name": request.tool.name,
                       "description": request.tool.description,
                       "input_schema": plainSchema(for: request.tool)]],
            "tool_choice": ["type": "tool", "name": request.tool.name],
        ]
    }

    func toolInput(from root: [String: Any]) throws -> [String: Any] {
        guard let content = root["content"] as? [[String: Any]] else {
            throw AIClient.CallError.noToolCall
        }
        for block in content where block["type"] as? String == "tool_use" {
            if let input = block["input"] as? [String: Any] { return input }
        }
        throw AIClient.CallError.noToolCall
    }

    func isRefusal(_ root: [String: Any]) -> Bool {
        (root["stop_reason"] as? String) == "refusal"
    }

    func isTruncated(_ root: [String: Any]) -> Bool {
        (root["stop_reason"] as? String) == "max_tokens"
    }

    // MARK: Models

    func modelsEndpoint() -> URL {
        // Constant string, so the force-unwrap can't fail: no user text goes into this URL.
        URL(string: "\(base)/models?limit=100")!
    }

    /// Every model this endpoint returns is a Messages-API model, so no filtering is needed — and
    /// `display_name` gives a properly formatted label for free.
    func parseModels(from root: [String: Any]) -> [AIModelInfo] {
        ((root["data"] as? [[String: Any]]) ?? []).compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return AIModelInfo(id: id, displayName: (item["display_name"] as? String) ?? id)
        }
    }
}
