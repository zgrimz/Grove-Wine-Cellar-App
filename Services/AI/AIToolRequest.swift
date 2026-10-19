import Foundation

/// One image attached to an AI request. Always JPEG in this app — ``VisionService`` re-encodes
/// every label photo before upload, so `mediaType` is a fact rather than a guess.
struct AIImage {
    var base64: String
    var mediaType: String
}

/// The single tool an ``AIToolRequest`` forces the model to call.
struct AITool {
    var name: String
    var description: String
    /// JSON-Schema `properties` for the tool's input object, in plain vendor-neutral form. Each
    /// ``AIWireFormat`` adapts it to its own dialect.
    var properties: [String: Any]
    /// Property names the model must supply. Anything left out may be omitted — the label scanner
    /// depends on that for details it can't read, which is why strict/structured-output modes that
    /// demand a fully-populated `required` are unusable here.
    var required: [String]
}

/// A vendor-neutral description of the only AI interaction this app performs: one single-turn
/// request that must come back as a call to `tool`.
///
/// Both features are shaped this way — one system prompt, one user message, optionally one image,
/// no history and no assistant prefill — so this covers them without a general conversation type.
struct AIToolRequest {
    var modelID: String
    /// Output budget, sized against Anthropic's accounting where it counts answer tokens only.
    /// Providers that spend the same allowance on reasoning scale it — see
    /// `AIWireFormat.scaledMaxTokens(_:)`.
    var maxTokens: Int
    var systemPrompt: String
    var userText: String
    var image: AIImage?
    var tool: AITool
    /// Request timeout, likewise scaled per provider by `AIWireFormat.scaledTimeout(_:)`.
    var timeout: TimeInterval
}
