import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case claude
    case openai
    case ollama

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        case .ollama: return "Ollama (local)"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-opus-5-5"
        case .openai: return "gpt-5-mini"
        case .ollama: return "llama3.2"
        }
    }

    var needsAPIKey: Bool { self != .ollama }
}

enum Tone: String, CaseIterable, Identifiable {
    case professional
    case friendly
    case concise
    case grammar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .professional: return "Professional"
        case .friendly: return "Friendly"
        case .concise: return "Concise"
        case .grammar: return "Fix grammar"
        }
    }

    var instruction: String {
        switch self {
        case .professional:
            return "Make it clear, polished and professional, but still natural for Slack. Not stiff or corporate."
        case .friendly:
            return "Make it warm, friendly and casual, like a good teammate. Keep it clear."
        case .concise:
            return "Make it as short and direct as possible without losing any information or requests."
        case .grammar:
            return "Only fix spelling, grammar, capitalization and punctuation. Do not change wording, tone or structure otherwise."
        }
    }
}

/// Non-secret preferences live in UserDefaults; API keys live in the Keychain (see Keychain.swift).
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var provider: Provider {
        didSet { defaults.set(provider.rawValue, forKey: "provider") }
    }

    @Published var defaultTone: Tone {
        didSet { defaults.set(defaultTone.rawValue, forKey: "defaultTone") }
    }

    @Published var customInstructions: String {
        didSet { defaults.set(customInstructions, forKey: "customInstructions") }
    }

    @Published var showFloatingButton: Bool {
        didSet { defaults.set(showFloatingButton, forKey: "showFloatingButton") }
    }

    @Published var ollamaURL: String {
        didSet { defaults.set(ollamaURL, forKey: "ollamaURL") }
    }

    private init() {
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .claude
        defaultTone = Tone(rawValue: defaults.string(forKey: "defaultTone") ?? "") ?? .professional
        customInstructions = defaults.string(forKey: "customInstructions") ?? ""
        showFloatingButton = defaults.object(forKey: "showFloatingButton") as? Bool ?? true
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434"
    }

    func model(for provider: Provider) -> String {
        let stored = defaults.string(forKey: "model.\(provider.rawValue)") ?? ""
        return stored.isEmpty ? provider.defaultModel : stored
    }

    func setModel(_ model: String, for provider: Provider) {
        defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "model.\(provider.rawValue)")
        objectWillChange.send()
    }
}
