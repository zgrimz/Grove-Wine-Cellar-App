import Foundation

/// Which vendor's API the AI features talk to.
///
/// The user picks one in Settings and it applies to both label scanning and pairing. The choice is
/// deliberately **device-local**, like the API key it depends on — see ``AISettings``.
enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openai

    var id: String { rawValue }

    /// Resolve a stored raw value. Never force-unwrap something that round-trips through storage:
    /// a value written by a newer build simply falls back to the provider this app started with.
    static func named(_ raw: String?) -> AIProvider {
        guard let raw, let provider = AIProvider(rawValue: raw) else { return .anthropic }
        return provider
    }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        }
    }

    /// Keychain account for this provider's key. Each provider keeps its own, so switching back
    /// and forth never costs the user a re-paste.
    ///
    /// Once shipped, these strings are permanent — changing one strands every existing user's key.
    /// See the warning in ``KeychainStore``.
    var keychainAccount: String {
        switch self {
        case .anthropic: return "anthropic.apiKey"
        case .openai: return "openai.apiKey"
        }
    }

    var keyFieldLabel: String {
        switch self {
        case .anthropic: return "Anthropic API Key"
        case .openai: return "OpenAI API Key"
        }
    }

    /// Where the user creates a key, named in the Settings footer.
    var consoleHost: String {
        switch self {
        case .anthropic: return "console.anthropic.com"
        case .openai: return "platform.openai.com/api-keys"
        }
    }

    var wire: AIWireFormat {
        switch self {
        case .anthropic: return AnthropicWire()
        case .openai: return OpenAIWire()
        }
    }
}
