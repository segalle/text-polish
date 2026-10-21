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

    /// Shown when the provider's model list can't be fetched (no key yet, offline).
    var fallbackModels: [String] {
        switch self {
        case .claude: return ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
        case .openai: return ["gpt-5-mini", "gpt-5"]
        case .ollama: return ["llama3.2"]
        }
    }
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

    /// How many alternative rewrites to ask for (1–3).
    @Published var suggestionCount: Int {
        didSet { defaults.set(suggestionCount, forKey: "suggestionCount") }
    }

    private init() {
        Self.migrateFromSlackPolish(into: defaults)
        suggestionCount = defaults.object(forKey: "suggestionCount") as? Int ?? 3
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .claude
        defaultTone = Tone(rawValue: defaults.string(forKey: "defaultTone") ?? "") ?? .professional
        customInstructions = defaults.string(forKey: "customInstructions") ?? ""
        showFloatingButton = defaults.object(forKey: "showFloatingButton") as? Bool ?? true
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434"
    }

    /// The app was called Slack Polish before; copy its preferences once.
    private static func migrateFromSlackPolish(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: "migratedFromSlackPolish") else { return }
        for (key, value) in defaults.persistentDomain(forName: "com.local.slackpolish") ?? [:]
        where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: "migratedFromSlackPolish")
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
