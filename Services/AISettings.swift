import Foundation
import Observation

/// User-configurable settings for the app's optional AI features: label scanning and pairing.
///
/// Two storage tiers, chosen by what the data is:
/// - **Keychain, device-local** — the API keys (``KeychainStore``). One per provider, all kept at
///   once so switching providers never costs the user a re-paste.
/// - **`UserDefaults`, device-local** — everything else: the on/off switch, the selected provider,
///   and the per-provider model choices.
///
/// **Nothing in here syncs, by design.** The switch and the model choices all hang off the one
/// thing that is device-local and must stay that way — the API key. A synced provider would point
/// another device at a vendor it has no key for, and a synced model id names a model that key
/// can't reach.
///
/// Injected app-wide from ``GroveWineCellarApp`` so Settings and both AI features share one source
/// of truth.
@Observable
final class AISettings {
    /// The master switch for every AI feature. Off by default for new installs: the rest of this
    /// app works entirely on-device, and this is the capability that sends the user's label photos
    /// and cellar list to a third party, so it is worth one unambiguous answer to "does this app
    /// talk to a vendor at all?". Upgrading installs that already had a key start switched on —
    /// see `init`.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    /// When the user acknowledged the AI disclosure — the alert Settings presents before the
    /// Enable AI Features switch turns on. A record of that consent; nothing in the app reads it
    /// back. Device-local like the rest of this type: the acknowledgment belongs to the device it
    /// was given on.
    static let disclosureAcknowledgedDateKey = "ai.disclosureAcknowledgedDate"

    /// Which vendor both AI features talk to.
    var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }

    // MARK: API keys

    // One stored property per provider rather than a single value swapped on provider change.
    // That is a safety property, not a style preference: `KeychainStore.set("")` *deletes* the
    // item, so with one swapped property the didSet ordering decides whether the outgoing
    // provider's key is written or erased — or whether one provider's key is sent to the other.
    // Split like this, neither failure is expressible.

    var anthropicKey: String {
        didSet { KeychainStore.set(anthropicKey, for: AIProvider.anthropic.keychainAccount) }
    }

    var openAIKey: String {
        didSet { KeychainStore.set(openAIKey, for: AIProvider.openai.keychainAccount) }
    }

    /// The active provider's key. Computed, so it cannot drift out of step with `provider`.
    var apiKey: String {
        get { key(for: provider) }
        set { setKey(newValue, for: provider) }
    }

    func key(for provider: AIProvider) -> String {
        switch provider {
        case .anthropic: return anthropicKey
        case .openai: return openAIKey
        }
    }

    func setKey(_ value: String, for provider: AIProvider) {
        switch provider {
        case .anthropic: anthropicKey = value
        case .openai: openAIKey = value
        }
    }

    /// True when the active provider has a non-blank key.
    var hasAPIKey: Bool { !trimmedKey.isEmpty }

    /// True when label scanning is set up end to end: switched on, a key present, and a model
    /// chosen. The model has to be part of this — model ids come from the provider's own list
    /// rather than a built-in default (see ``AIModelCatalog``), so "key but no model yet" is a
    /// real state a new user passes through, not a should-never-happen.
    var canScanLabels: Bool { isEnabled && hasAPIKey && hasLabelScanningModel }

    /// True when pairing has everything it needs.
    var canPair: Bool { isEnabled && hasAPIKey && hasPairingModel }

    var hasLabelScanningModel: Bool { !labelScanningModelID.isEmpty }
    var hasPairingModel: Bool { !pairingModelID.isEmpty }

    /// The key as it should go on the wire. Trimmed of newlines as well as spaces: a key pasted
    /// with a trailing newline is an invalid HTTP header value.
    var trimmedKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Providers with a key stored on this device, whichever one is currently selected.
    ///
    /// Deliberately not scoped to `provider`: keys are kept per provider so switching back and
    /// forth doesn't lose one, which means a user can have a key stored for a provider the picker
    /// isn't showing. A deletion control has to reach every stored key, not just the selected
    /// provider's, or it leaves one behind and reports success.
    var storedKeyProviders: [AIProvider] {
        AIProvider.allCases.filter { !key(for: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var hasAnyStoredKey: Bool { !storedKeyProviders.isEmpty }

    /// Erase every stored API key, model choice, and cached model list.
    ///
    /// Turning AI off is not deletion: the switch stops future requests and deliberately keeps the
    /// setup. This is how a user who wants the secret *gone* says so. Leaves `isEnabled` and the
    /// disclosure-acknowledgment date alone — the first is the user's own switch to hold, and the
    /// second is the record that consent was given, not a credential.
    func deleteAllCredentials() {
        for provider in AIProvider.allCases {
            // Empty string routes through `KeychainStore.set`, which deletes the item outright
            // rather than storing a blank — see the note above the per-provider properties.
            setKey("", for: provider)
            defaults.removeObject(forKey: Keys.labelScanningModel(provider))
            defaults.removeObject(forKey: Keys.pairingModel(provider))
        }
        // The plaintext key too, in case a failed Keychain write left it waiting for `init` to
        // retry the move — otherwise the next launch would hand the deleted key back.
        defaults.removeObject(forKey: Keys.legacyAPIKey)
        // `persist` skips absent entries, so emptying the dictionaries alone would leave the
        // defaults keys behind. They are removed above; these keep memory in step.
        labelScanningModels = [:]
        pairingModels = [:]

        AIModelCatalog.forgetAll()
    }

    // MARK: Model selection

    /// Selected model for label scanning with the current provider.
    ///
    /// Empty until one is chosen. There is no hardcoded fallback on purpose: a built-in id that the
    /// provider has since retired would look like a working setting and fail only on first use, so
    /// Settings fills this in from the provider's own list instead (see ``AIModelCatalog``).
    var labelScanningModelID: String {
        get { labelScanningModels[provider.rawValue] ?? "" }
        set { labelScanningModels[provider.rawValue] = newValue }
    }

    /// Selected model for pairing. Independent of the scanning model — scanning leans on vision,
    /// pairing on reasoning, so the cost/quality sweet spots differ.
    var pairingModelID: String {
        get { pairingModels[provider.rawValue] ?? "" }
        set { pairingModels[provider.rawValue] = newValue }
    }

    private var labelScanningModels: [String: String] {
        didSet { persist(labelScanningModels, under: Keys.labelScanningModel) }
    }

    private var pairingModels: [String: String] {
        didSet { persist(pairingModels, under: Keys.pairingModel) }
    }

    // MARK: Storage keys

    private enum Keys {
        static let enabled = "ai.enabled"
        static let provider = "ai.provider"

        static func labelScanningModel(_ provider: AIProvider) -> String {
            "ai.labelScanning.modelID.\(provider.rawValue)"
        }

        static func pairingModel(_ provider: AIProvider) -> String {
            "ai.pairing.modelID.\(provider.rawValue)"
        }

        // Pre-provider keys, from when the app only spoke to Claude and kept the key in plain
        // `UserDefaults`. Read once by `migrateLegacyAPIKey`; never written.
        static let legacyAPIKey = "claudeAPIKey"
        static let legacyModel = "claudeModel"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard

        // Before this type existed AI had no switch: a key meant it was on. Carry that over so an
        // upgrade doesn't quietly turn off features the user was already using. Seeded only while
        // the switch has never been stored, so it can't override a choice made since.
        let hadLegacyKey = Self.migrateLegacyAPIKey(defaults)
        if hadLegacyKey, defaults.object(forKey: Keys.enabled) == nil {
            defaults.set(true, forKey: Keys.enabled)
        }

        isEnabled = defaults.bool(forKey: Keys.enabled)
        provider = AIProvider.named(defaults.string(forKey: Keys.provider))

        anthropicKey = KeychainStore.get(AIProvider.anthropic.keychainAccount) ?? ""
        openAIKey = KeychainStore.get(AIProvider.openai.keychainAccount) ?? ""

        var labelScanning: [String: String] = [:]
        var pairing: [String: String] = [:]
        for provider in AIProvider.allCases {
            labelScanning[provider.rawValue] = defaults.string(forKey: Keys.labelScanningModel(provider))
            pairing[provider.rawValue] = defaults.string(forKey: Keys.pairingModel(provider))
        }
        // didSet does not fire for these initial assignments, so nothing is written back here.
        labelScanningModels = labelScanning
        pairingModels = pairing
    }

    /// Move the API key out of plain-text `UserDefaults`, where every earlier build kept it, and
    /// into the Keychain. Returns true when there was a legacy key.
    ///
    /// The plaintext copy is removed only once the Keychain reads the key back: a failed write must
    /// not cost the user their key, so it stays put and the move is retried on the next launch.
    /// Idempotent by absence rather than a "migrated" flag — once the legacy entry is gone there is
    /// nothing left to do, and no second piece of state to keep true.
    ///
    /// The legacy model choice is dropped rather than carried over. It came from a hardcoded list
    /// of ids — exactly the rot ``AIModelCatalog`` exists to avoid — so the first model refresh
    /// picks a current one from the provider's own list instead.
    private static func migrateLegacyAPIKey(_ defaults: UserDefaults) -> Bool {
        defaults.removeObject(forKey: Keys.legacyModel)

        let legacy = (defaults.string(forKey: Keys.legacyAPIKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !legacy.isEmpty else {
            defaults.removeObject(forKey: Keys.legacyAPIKey)
            return false
        }

        let account = AIProvider.anthropic.keychainAccount
        if (KeychainStore.get(account) ?? "").isEmpty {
            KeychainStore.set(legacy, for: account)
        }
        if !(KeychainStore.get(account) ?? "").isEmpty {
            defaults.removeObject(forKey: Keys.legacyAPIKey)
        }
        return true
    }

    private func persist(_ models: [String: String], under key: (AIProvider) -> String) {
        for provider in AIProvider.allCases {
            guard let value = models[provider.rawValue] else { continue }
            defaults.set(value, forKey: key(provider))
        }
    }
}
