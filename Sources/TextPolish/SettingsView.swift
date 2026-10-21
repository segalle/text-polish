import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var apiKey = ""
    @State private var models: [String] = []
    @State private var selectedModel = ""
    @State private var customModel = ""
    @State private var loadingModels = false
    @State private var saved = false
    @State private var trusted = SlackAccessibility.isTrusted

    private static let customTag = "__custom__"

    var body: some View {
        Form {
            Section("Model") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { Text($0.label).tag($0) }
                }
                if settings.provider.needsAPIKey {
                    HStack {
                        SecureField("API key", text: $apiKey, prompt: Text("Stored in your Keychain"))
                        Button("Save") { saveKey() }
                        if saved {
                            Image(systemName: "checkmark").foregroundStyle(.green)
                        }
                    }
                } else {
                    TextField("Ollama URL", text: $settings.ollamaURL)
                        .onSubmit { Task { await loadModels() } }
                }
                HStack {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                        Divider()
                        Text("Custom…").tag(Self.customTag)
                    }
                    .onChange(of: selectedModel) { _ in applyModel() }
                    if loadingModels {
                        ProgressView().controlSize(.small)
                    } else {
                        Button {
                            Task { await loadModels() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Refresh model list")
                    }
                }
                if selectedModel == Self.customTag {
                    TextField("Model ID", text: $customModel, prompt: Text("e.g. \(settings.provider.defaultModel)"))
                        .onSubmit(applyModel)
                        .onChange(of: customModel) { _ in applyModel() }
                }
            }

            Section("Rewriting") {
                Picker("Default tone", selection: $settings.defaultTone) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
                Picker("Suggestions", selection: $settings.suggestionCount) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)
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
        .task(id: settings.provider) { await load() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = SlackAccessibility.isTrusted
        }
    }

    private func load() async {
        apiKey = Keychain.apiKey(for: settings.provider) ?? ""
        saved = false
        await loadModels()
    }

    private func loadModels() async {
        let provider = settings.provider
        let current = settings.model(for: provider)
        models = [current]
        selectedModel = current
        loadingModels = true
        let fetched = await ModelCatalog.fetch(for: provider, settings: settings)
        guard provider == settings.provider else { return }
        loadingModels = false
        models = fetched
        if fetched.contains(current) {
            selectedModel = current
        } else {
            customModel = current
            selectedModel = Self.customTag
        }
    }

    private func applyModel() {
        let model = selectedModel == Self.customTag ? customModel : selectedModel
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        settings.setModel(model, for: settings.provider)
    }

    private func saveKey() {
        Keychain.setAPIKey(apiKey, for: settings.provider)
        saved = true
        Task { await loadModels() }
    }
}
