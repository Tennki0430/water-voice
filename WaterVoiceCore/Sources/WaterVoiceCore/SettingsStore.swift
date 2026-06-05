import Foundation

/// User preferences persisted via an injected `KeyValueStore`.
public final class SettingsStore {
    private let store: KeyValueStore

    private enum Key {
        static let language = "watervoice.languageCode"
        static let hotKey = "watervoice.hotKeyIdentifier"
        static let prompt = "watervoice.customPrompt"
        static let tone = "watervoice.defaultTone"
        static let dictionary = "watervoice.dictionaryEntries"
        static let appProfiles = "watervoice.appProfiles"
    }

    public init(store: KeyValueStore) {
        self.store = store
    }

    public var languageCode: String {
        get { store.string(forKey: Key.language) ?? "ja-JP" }
        set { store.set(newValue, forKey: Key.language) }
    }

    public var hotKeyIdentifier: String {
        get { store.string(forKey: Key.hotKey) ?? "rightOption" }
        set { store.set(newValue, forKey: Key.hotKey) }
    }

    /// Optional override for the formatter instructions; nil means use FormatterPrompt defaults.
    public var customPrompt: String? {
        get { store.string(forKey: Key.prompt) }
        set { store.set(newValue, forKey: Key.prompt) }
    }

    /// Default output tone applied when no per-app profile matches.
    public var defaultTone: DictationTone {
        get { store.string(forKey: Key.tone).flatMap(DictationTone.init(rawValue:)) ?? .asIs }
        set { store.set(newValue.rawValue, forKey: Key.tone) }
    }

    /// Custom-vocabulary entries (names, jargon) persisted as JSON.
    public var dictionaryEntries: [DictionaryEntry] {
        get { decode([DictionaryEntry].self, forKey: Key.dictionary) ?? [] }
        set { encode(newValue, forKey: Key.dictionary) }
    }

    /// Per-app tone overrides keyed by bundle identifier, persisted as JSON.
    public var appProfiles: [String: DictationTone] {
        get { decode([String: DictationTone].self, forKey: Key.appProfiles) ?? [:] }
        set { encode(newValue, forKey: Key.appProfiles) }
    }

    /// Resolver combining the default tone with per-app overrides.
    public var profileResolver: AppProfileResolver {
        AppProfileResolver(defaultTone: defaultTone, profiles: appProfiles)
    }

    // MARK: - JSON helpers

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let json = store.string(forKey: key),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else { return }
        store.set(json, forKey: key)
    }
}
