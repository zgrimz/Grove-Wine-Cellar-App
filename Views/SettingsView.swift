import SwiftUI

/// App settings: the AI features switch, provider and key, and a model for each feature.
struct SettingsView: View {
    @Environment(AISettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showingAIConsent = false
    @State private var showingCredentialDeleteConfirm = false
    @State private var modelRefresh: ModelRefresh = .idle

    private enum ModelRefresh: Equatable {
        case idle
        case loading
        case loaded(Int)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable AI Features", isOn: aiEnableBinding)
                } header: {
                    Text("AI Features")
                } footer: {
                    Text("Scan wine labels and get pairing recommendations from your chosen AI provider, using your own API key. Turning AI off keeps your keys and model choices.")
                }

                aiConfigurationSections

                credentialsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Keyed so it re-runs when AI is switched on, the provider changes, or a key first
            // appears — not on every keystroke, since `hasAPIKey` only flips once. That gives the
            // intended flow: pick a provider, paste a key, and the real model list arrives behind
            // the picker.
            .task(id: "\(settings.isEnabled)|\(settings.provider.rawValue)|\(settings.hasAPIKey)") {
                guard settings.isEnabled else { return }
                await refreshModels(force: false)
                adoptPreferredModels()
            }
            .confirmationDialog("Delete API Keys?", isPresented: $showingCredentialDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    settings.deleteAllCredentials()
                    modelRefresh = .idle
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes \(credentialDeleteSubject) from this device and resets your model choices. To revoke these keys, delete them in your provider account too.")
            }
            .alert("Turn On AI Features?", isPresented: $showingAIConsent) {
                Button("Turn On") {
                    settings.isEnabled = true
                    UserDefaults.standard.set(Date(), forKey: AISettings.disclosureAcknowledgedDateKey)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("AI features send your wine label photos and your cellar list to your chosen provider (Anthropic or OpenAI) using your own API key. Your provider’s terms apply.\n\nEntering a key or switching providers sends that provider’s key to load the available models. Grove Wine Cellar never receives any of it.")
            }
        }
    }

    /// Provider, key, and model pickers — everything that only means anything while AI is on.
    @ViewBuilder
    private var aiConfigurationSections: some View {
        // Own `@Bindable`, because the environment value can't produce bindings by itself.
        @Bindable var settings = settings
        if settings.isEnabled {
            Section {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
                }
                SecureField(settings.provider.keyFieldLabel, text: $settings.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await refreshModels(force: true) } }
                if settings.hasAPIKey {
                    Button { Task { await refreshModels(force: true) } } label: {
                        HStack {
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                            if modelRefresh == .loading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(modelRefresh == .loading)
                    switch modelRefresh {
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    case .loaded(let count):
                        Text("\(count) model\(count == 1 ? "" : "s") available with this key.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    case .idle, .loading:
                        EmptyView()
                    }
                } else {
                    Label("Enter your API key to continue.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Provider")
            } footer: {
                Text("Get an API key at \(settings.provider.consoleHost). Keys are stored in this device’s Keychain and sent only to their provider. Your provider’s terms and limits apply.")
            }

            Section {
                AIModelPicker(title: "Model", provider: settings.provider, hasAPIKey: settings.hasAPIKey,
                              selection: $settings.labelScanningModelID)
                if settings.hasAPIKey, !settings.hasLabelScanningModel {
                    Label("Choose a model to start scanning labels.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Label Scanning")
            } footer: {
                Text("Photograph a label and the details are filled in for you to review. Photos are sent to \(settings.provider.displayName).")
            }

            Section {
                AIModelPicker(title: "Model", provider: settings.provider, hasAPIKey: settings.hasAPIKey,
                              selection: $settings.pairingModelID)
                if settings.hasAPIKey, !settings.hasPairingModel {
                    Label("Choose a model to get pairings.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Pairing")
            } footer: {
                Text("Picks a bottle from your cellar for a dish or occasion, so your cellar list is sent to \(settings.provider.displayName). It can use a different model than scanning — a more capable one helps here.")
            }
        }
    }

    /// Shown whenever a key is stored — including with AI switched off, which is exactly when a
    /// user goes looking for it and when the rest of the AI configuration disappears.
    @ViewBuilder
    private var credentialsSection: some View {
        if settings.hasAnyStoredKey {
            Section {
                Button(role: .destructive) {
                    showingCredentialDeleteConfirm = true
                } label: {
                    Label("Delete API Keys", systemImage: "key.slash")
                }
            } footer: {
                Text(credentialDeleteFooter)
            }
        }
    }

    private var credentialDeleteSubject: String {
        let names = settings.storedKeyProviders.map(\.displayName)
        return names.count == 1 ? "your \(names[0]) API key" : "your \(names.joined(separator: " and ")) API keys"
    }

    private var credentialDeleteFooter: String {
        let stored = settings.storedKeyProviders.count == 1
            ? "1 key saved on this device."
            : "\(settings.storedKeyProviders.count) keys saved on this device."
        return "\(stored) Deleting them also resets your model choices."
    }

    /// The Enable AI Features switch, gated: flipping it on presents the disclosure alert, and
    /// nothing is enabled until "Turn On" is tapped. This one gate covers every downstream
    /// transmission (key entry, label scans, pairings), because none of them can run until this
    /// switch is on. Turning off stays immediate.
    private var aiEnableBinding: Binding<Bool> {
        Binding(
            get: { settings.isEnabled },
            set: { newValue in
                if newValue { showingAIConsent = true } else { settings.isEnabled = false }
            }
        )
    }

    /// Ask the provider which models this key can actually use. Failure is never fatal: the
    /// picker keeps whatever it was already showing, so a refresh that can't reach the network
    /// leaves the user no worse off than before.
    private func refreshModels(force: Bool) async {
        let provider = settings.provider
        let key = settings.trimmedKey
        guard !key.isEmpty else {
            modelRefresh = .idle
            return
        }
        guard force || !AIModelCatalog.hasFetchedModels(for: provider) else {
            // Already cached. Clear any status left from the previous provider, which would
            // otherwise read as describing this one.
            modelRefresh = .idle
            return
        }

        modelRefresh = .loading
        do {
            let models = try await AIModelCatalog.refresh(provider: provider, apiKey: key)
            modelRefresh = .loaded(models.count)
            adoptPreferredModels()
        } catch let error as AIClient.CallError {
            modelRefresh = .failed(error.summary(provider: provider))
        } catch {
            modelRefresh = .failed(error.localizedDescription)
        }
    }

    /// Choose a model for the current provider when the user hasn't, ranking whatever that
    /// provider actually returned. Never overrides an existing choice — including one typed into
    /// Enter Model ID — so this only ever fills a blank.
    private func adoptPreferredModels() {
        let models = AIModelCatalog.models(for: settings.provider)
        guard !models.isEmpty else { return }
        if settings.labelScanningModelID.isEmpty,
           let pick = AIModelCatalog.preferred(from: models, for: .labelScanning) {
            settings.labelScanningModelID = pick
        }
        if settings.pairingModelID.isEmpty,
           let pick = AIModelCatalog.preferred(from: models, for: .pairing) {
            settings.pairingModelID = pick
        }
    }
}

/// A model picker plus a free-text escape hatch.
///
/// The currently-selected id **always** gets a row. SwiftUI renders a blank selection, with no
/// warning at all, whenever the binding matches no child's tag — and between fetched lists that
/// vary by key and ids typed in by hand, a selection outside the visible list is routine here
/// rather than exotic.
private struct AIModelPicker: View {
    let title: String
    let provider: AIProvider
    let hasAPIKey: Bool
    @Binding var selection: String

    private var rows: [AIModelInfo] {
        var models = AIModelCatalog.models(for: provider)
        if !selection.isEmpty, !models.contains(where: { $0.id == selection }) {
            models.insert(AIModelInfo(id: selection, displayName: selection), at: 0)
        }
        return models
    }

    var body: some View {
        if rows.isEmpty {
            // No list and no selection: say so rather than rendering an empty Picker, which
            // SwiftUI draws as a blank row with no explanation.
            LabeledContent(title) {
                Text(hasAPIKey ? "No models loaded" : "Add a key to load models").foregroundStyle(.secondary)
            }
        } else {
            Picker(title, selection: $selection) {
                ForEach(rows) { Text($0.displayName).tag($0.id) }
            }
        }
        DisclosureGroup("Enter Model ID") {
            TextField("Model ID", text: $selection)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote.monospaced())
        }
    }
}

#Preview {
    SettingsView()
        .environment(AISettings())
}
