import Foundation

/// OpenAI's Chat Completions API, using a forced `function` tool call for structured output.
///
/// Deliberately **not** using structured outputs' `strict: true` mode. Strict mode requires every
/// property to appear in `required` (plus `additionalProperties: false`), which is incompatible
/// with the label scanner leaving out details it can't read. The cost is that enums become strong
/// hints rather than hard constraints, so both features read the tool input leniently.
struct OpenAIWire: AIWireFormat {
    private let base = "https://api.openai.com/v1"

    func endpoint(modelID: String) throws -> URL {
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw AIClient.CallError.transport("Couldn't build the OpenAI endpoint URL.")
        }
        return url
    }

    func headers(apiKey: String) -> [String: String] {
        ["Content-Type": "application/json",
         "Authorization": "Bearer \(apiKey)"]
    }

    func requestBody(for request: AIToolRequest) -> [String: Any] {
        var content: [[String: Any]] = []
        // Image before text, matching the Anthropic wire format.
        if let image = request.image {
            content.append(["type": "image_url",
                            "image_url": ["url": "data:\(image.mediaType);base64,\(image.base64)"]])
        }
        content.append(["type": "text", "text": request.userText])

        return [
            "model": request.modelID,
            // `max_completion_tokens`, not `max_tokens`: the latter is rejected outright by the
            // reasoning models. This one covers reasoning *and* the answer — hence the scaling.
            "max_completion_tokens": scaledMaxTokens(request.maxTokens),
            "messages": [
                ["role": "system", "content": request.systemPrompt],
                ["role": "user", "content": content],
            ],
            "tools": [["type": "function",
                       "function": ["name": request.tool.name,
                                    "description": request.tool.description,
                                    "parameters": plainSchema(for: request.tool)]]],
            "tool_choice": ["type": "function", "function": ["name": request.tool.name]],
        ]
    }

    func toolInput(from root: [String: Any]) throws -> [String: Any] {
        guard let calls = message(root)?["tool_calls"] as? [[String: Any]] else {
            throw AIClient.CallError.noToolCall
        }
        for call in calls {
            // Unlike Anthropic's, the arguments arrive as a JSON *string* that has to be parsed a
            // second time. An empty string would make JSONSerialization throw.
            guard let function = call["function"] as? [String: Any],
                  let arguments = function["arguments"] as? String,
                  !arguments.isEmpty,
                  let parsed = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8)))
                      as? [String: Any]
            else { continue }
            return parsed
        }
        throw AIClient.CallError.noToolCall
    }

    func isRefusal(_ root: [String: Any]) -> Bool {
        if message(root)?["refusal"] is String { return true }
        return finishReason(root) == "content_filter"
    }

    func isTruncated(_ root: [String: Any]) -> Bool {
        finishReason(root) == "length"
    }

    /// Reasoning tokens are billed against the same allowance as the answer, so a budget sized for
    /// Claude's answer-only accounting can be spent entirely on thinking — leaving a truncated
    /// response carrying no tool call at all.
    func scaledMaxTokens(_ base: Int) -> Int { base * 8 }

    func scaledTimeout(_ base: TimeInterval) -> TimeInterval { base * 1.5 }

    private func message(_ root: [String: Any]) -> [String: Any]? {
        ((root["choices"] as? [[String: Any]])?.first)?["message"] as? [String: Any]
    }

    private func finishReason(_ root: [String: Any]) -> String? {
        ((root["choices"] as? [[String: Any]])?.first)?["finish_reason"] as? String
    }

    // MARK: Models

    func modelsEndpoint() -> URL { URL(string: "\(base)/models")! }

    /// The messy one. This endpoint returns *everything* on the account — embeddings, speech,
    /// transcription, moderation, image models, fine-tunes — and carries no capability metadata at
    /// all, so chat models that can handle vision and function calling have to be recognised by
    /// name. Anything the filter wrongly drops is still reachable through Enter Model ID.
    func parseModels(from root: [String: Any]) -> [AIModelInfo] {
        let families = ["gpt-", "o1", "o3", "o4"]
        let excluded = ["embedding", "whisper", "tts", "audio", "realtime", "moderation",
                        "dall-e", "image", "search", "transcribe", "instruct", "codex",
                        "computer-use", "davinci", "babbage", "deep-research"]
        return ((root["data"] as? [[String: Any]]) ?? []).compactMap { item -> AIModelInfo? in
            guard let id = item["id"] as? String else { return nil }
            let name = id.lowercased()
            guard families.contains(where: { name.hasPrefix($0) }) else { return nil }
            guard !excluded.contains(where: { name.contains($0) }) else { return nil }
            return AIModelInfo(id: id, displayName: id)
        }
        // Unordered from the API, and long even after filtering — sort it so it can be scanned.
        .sorted { $0.id < $1.id }
    }
}
