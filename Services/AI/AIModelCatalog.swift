import Foundation

/// The model lists shown in Settings, fetched from each provider's own models endpoint.
///
/// There is deliberately **no built-in list of model ids**. Hardcoded ids rot, and a rotted id is
/// worse than a missing one, because it reads as a working configuration and fails only at the
/// point of use, with a 404 the user has no way to interpret. So a provider's own answer is the
/// only source, and until a key produces one there is simply no list and no selection.
///
/// The one piece of taste that stays in the app is *ranking* (see ``AIModelCatalog/ModelRole``),
/// which is applied to whatever the provider returned. Its worst case is a suboptimal real model,
/// never an id that doesn't exist.
enum AIModelCatalog {
    /// What a model is being chosen for. Label scanning and pairing want opposite ends of a
    /// provider's range, so each ranks the fetched list its own way.
    enum ModelRole {
        /// Reading a label photo: vision matters, deep reasoning doesn't. Favour the quick models.
        case labelScanning
        /// Reasoning across a whole cellar. Favour the capable ones.
        case pairing

        /// Substrings tried in order against the provider's own model ids, cheapest-first for
        /// scanning and strongest-first for pairing. Deliberately loose: these match names, they
        /// don't assert that any particular model exists. `pro` is OpenAI's `-pro` tier.
        var ranking: [String] {
            switch self {
            case .labelScanning: return ["haiku", "mini", "sonnet", "gpt-4o", "gpt-5", "pro", "opus"]
            case .pairing: return ["opus", "pro", "gpt-5", "sonnet", "gpt-4o", "haiku", "mini"]
            }
        }
    }

    /// The best available model for `role` out of what the provider actually offers, or nil when
    /// nothing has been fetched yet. Falls through to the first model rather than giving up, so a
    /// provider whose naming this app has never seen still gets a usable answer.
    static func preferred(from models: [AIModelInfo], for role: ModelRole) -> String? {
        for token in role.ranking {
            if let match = models.first(where: { $0.id.lowercased().contains(token) }) {
                return match.id
            }
        }
        return models.first?.id
    }

    /// What the picker shows for a provider: whatever its last successful fetch returned. Empty
    /// until then — that empty state is the honest one, and Settings surfaces it.
    static func models(for provider: AIProvider) -> [AIModelInfo] { cached(for: provider) }

    /// True once a list has been fetched, so the automatic refresh runs only when it would add
    /// something.
    static func hasFetchedModels(for provider: AIProvider) -> Bool { !cached(for: provider).isEmpty }

    /// Fetch and cache. Returns the new list so the caller can report how many arrived.
    @discardableResult
    static func refresh(provider: AIProvider, apiKey: String) async throws -> [AIModelInfo] {
        let models = try await AIClient.availableModels(provider: provider, apiKey: apiKey)
        // An empty result means the filter matched nothing, not that the account has no models —
        // keep whatever is already cached rather than emptying the picker.
        guard !models.isEmpty else { return self.models(for: provider) }
        cache(models, for: provider)
        return models
    }

    /// Drop every cached provider model list. Called when the user deletes their credentials:
    /// the list was fetched *with* the key being deleted and names what that account could reach,
    /// so leaving it behind would leave a readable trace of an account the user just disowned.
    static func forgetAll() {
        for provider in AIProvider.allCases {
            UserDefaults.standard.removeObject(forKey: cacheKey(provider))
        }
    }

    // MARK: Cache
    //
    // Local-only on purpose: this is derived data, scoped to one device's key, and re-fetchable.

    private static func cacheKey(_ provider: AIProvider) -> String { "ai.models.\(provider.rawValue)" }

    private static func cached(for provider: AIProvider) -> [AIModelInfo] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(provider)),
              let models = try? JSONDecoder().decode([AIModelInfo].self, from: data) else { return [] }
        return models
    }

    private static func cache(_ models: [AIModelInfo], for provider: AIProvider) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(provider))
    }
}
