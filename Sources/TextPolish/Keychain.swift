import Foundation
import Security

/// Stores one API key per provider as a generic password in the login keychain.
enum Keychain {
    private static let service = "com.local.textpolish"
    /// The app was called Slack Polish before; keys saved under that name move over on first read.
    private static let legacyService = "com.local.slackpolish"

    static func apiKey(for provider: Provider) -> String? {
        if let key = read(service: service, provider: provider) {
            return key
        }
        guard let legacy = read(service: legacyService, provider: provider) else { return nil }
        setAPIKey(legacy, for: provider)
        return legacy
    }

    private static func read(service: String, provider: Provider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    @discardableResult
    static func setAPIKey(_ key: String, for provider: Provider) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        SecItemDelete(match as CFDictionary)
        if trimmed.isEmpty { return true }

        var add = match
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrLabel as String] = "Text Polish \(provider.label) API key"
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
