import Foundation

/// One model offered by a provider, as shown in the Settings picker.
struct AIModelInfo: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
}

/// Translates this app's vendor-neutral ``AIToolRequest`` into one provider's wire format, and
/// reads that provider's response back out again.
protocol AIWireFormat {
    /// Where to POST a request for `modelID`. Throws rather than force-unwrapping, because the
    /// model id can be free text the user typed into the Enter Model ID field.
    func endpoint(modelID: String) throws -> URL
    func headers(apiKey: String) -> [String: String]
    func requestBody(for request: AIToolRequest) -> [String: Any]

    /// Pull the forced tool call's arguments out of a decoded response body.
    func toolInput(from root: [String: Any]) throws -> [String: Any]

    /// True when the model declined on safety or policy grounds.
    func isRefusal(_ root: [String: Any]) -> Bool
    /// True when the response hit its output ceiling before finishing the tool call.
    func isTruncated(_ root: [String: Any]) -> Bool
    /// True when this status and body mean "your API key is wrong". Deliberately not a bare
    /// `status == 401` check: nothing obliges a provider to reject a bad key with 401.
    func isAuthFailure(status: Int, root: [String: Any]?) -> Bool

    /// Scale the Anthropic-sized output budget into this provider's accounting.
    func scaledMaxTokens(_ base: Int) -> Int
    /// Scale the Anthropic-sized timeout likewise.
    func scaledTimeout(_ base: TimeInterval) -> TimeInterval

    func modelsEndpoint() -> URL
    func parseModels(from root: [String: Any]) -> [AIModelInfo]
}

extension AIWireFormat {
    func scaledMaxTokens(_ base: Int) -> Int { base }
    func scaledTimeout(_ base: TimeInterval) -> TimeInterval { base }
    func isAuthFailure(status: Int, root: [String: Any]?) -> Bool { status == 401 || status == 403 }

    /// The tool's input schema in plain JSON Schema. `required` is **omitted** when empty rather
    /// than sent as `[]` — Anthropic tolerates the empty array, OpenAI is happier without it, and
    /// one shape across every provider is one fewer thing to reason about.
    func plainSchema(for tool: AITool) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": tool.properties]
        if !tool.required.isEmpty { schema["required"] = tool.required }
        return schema
    }
}

/// Every provider this app supports reports failures as `{"error": {"message": …}}`, so this is
/// shared rather than a per-provider requirement.
func aiErrorMessage(from data: Data, root: [String: Any]?) -> String {
    if let error = root?["error"] as? [String: Any], let message = error["message"] as? String {
        return message
    }
    return String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown error"
}
