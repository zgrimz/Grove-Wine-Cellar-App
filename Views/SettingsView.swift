import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeAPIKey") private var apiKey: String = ""
    @AppStorage("claudeModel") private var model: String = "claude-sonnet-4-20250514"
    @Environment(\.dismiss) private var dismiss
    
    private let availableModels = [
        "claude-opus-4-20250514",
        "claude-sonnet-4-20250514",
        "claude-3-7-sonnet-20250219",
        "claude-3-5-haiku-20241022"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Claude API Configuration") {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Model", selection: $model) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Text("Your API key is stored securely on this device and is only used to make requests to the Claude API.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}