import Foundation

/// Lists the models the user's account (or local Ollama) can actually use.
enum ModelCatalog {
    static func fetch(for provider: Provider, settings: Settings) async -> [String] {
        let models: [String]
        switch provider {
        case .claude:
            models = await fetchClaude()
        case .openai:
            models = await fetchOpenAI()
        case .ollama:
            models = await fetchOllama(baseURL: settings.ollamaURL)
        }
        return models.isEmpty ? provider.fallbackModels : models
    }

    private static func fetchClaude() async -> [String] {
        guard let key = Keychain.apiKey(for: .claude) else { return [] }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=100")!)
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // The API returns newest first, which is the order we want in the menu.
        return await ids(from: request, list: "data", field: "id")
    }

    private static func fetchOpenAI() async -> [String] {
        guard let key = Keychain.apiKey(for: .openai) else { return [] }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        let excluded = ["audio", "realtime", "tts", "transcribe", "image", "search", "embedding", "moderation", "instruct"]
        return await ids(from: request, list: "data", field: "id")
            .filter { id in
                (id.hasPrefix("gpt-") || id.hasPrefix("o")) && !excluded.contains { id.contains($0) }
            }
            .sorted()
    }

    private static func fetchOllama(baseURL: String) async -> [String] {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(base)/api/tags") else { return [] }
        return await ids(from: URLRequest(url: url), list: "models", field: "name").sorted()
    }

    private static func ids(from request: URLRequest, list: String, field: String) async -> [String] {
        var request = request
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json[list] as? [[String: Any]]
        else { return [] }
        return items.compactMap { $0[field] as? String }
    }
}
