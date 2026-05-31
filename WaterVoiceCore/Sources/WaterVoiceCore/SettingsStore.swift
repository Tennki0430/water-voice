import Foundation

/// User preferences persisted via an injected `KeyValueStore`.
public final class SettingsStore {
    private let store: KeyValueStore

    private enum Key {
        static let language = "watervoice.languageCode"
        static let hotKey = "watervoice.hotKeyIdentifier"
        static let prompt = "watervoice.customPrompt"
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
}
