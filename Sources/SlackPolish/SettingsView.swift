import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var apiKey = ""
    @State private var model = ""
    @State private var saved = false
    @State private var trusted = SlackAccessibility.isTrusted

    var body: some View {
        Form {
            Section("Model") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { Text($0.label).tag($0) }
                }
                TextField("Model", text: $model, prompt: Text(settings.provider.defaultModel))
                if settings.provider.needsAPIKey {
                    SecureField("API key", text: $apiKey, prompt: Text("Stored in your Keychain"))
                } else {
                    TextField("Ollama URL", text: $settings.ollamaURL)
                }
                HStack {
                    Spacer()
                    if saved {
                        Text("Saved").foregroundStyle(.secondary)
                    }
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }

            Section("Rewriting") {
                Picker("Default tone", selection: $settings.defaultTone) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your style preferences (optional)")
                    TextEditor(text: $settings.customInstructions)
                        .font(.body)
                        .frame(height: 70)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                    Text("For example: \"American English. No exclamation marks. Keep it short.\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Show the ✨ button next to Slack's message box", isOn: $settings.showFloatingButton)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Accessibility access is on" : "Turn on Accessibility access to read and replace Slack drafts")
                    Spacer()
                    if !trusted {
                        Button("Open settings") {
                            SlackAccessibility.requestTrust()
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear(perform: load)
        .onChange(of: settings.provider) { _ in load() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = SlackAccessibility.isTrusted
        }
    }

    private func load() {
        apiKey = Keychain.apiKey(for: settings.provider) ?? ""
        let current = settings.model(for: settings.provider)
        model = current == settings.provider.defaultModel ? "" : current
        saved = false
    }

    private func save() {
        settings.setModel(model, for: settings.provider)
        if settings.provider.needsAPIKey {
            Keychain.setAPIKey(apiKey, for: settings.provider)
        }
        saved = true
    }
}
