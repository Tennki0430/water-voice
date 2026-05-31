import XCTest
@testable import WaterVoiceCore

final class SettingsStoreTests: XCTestCase {
    final class MemoryStore: KeyValueStore {
        var dict: [String: String] = [:]
        func string(forKey key: String) -> String? { dict[key] }
        func set(_ value: String?, forKey key: String) {
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
        }
    }

    func test_defaults_whenStoreEmpty() {
        let s = SettingsStore(store: MemoryStore())
        XCTAssertEqual(s.languageCode, "ja-JP")
        XCTAssertEqual(s.hotKeyIdentifier, "rightOption")
    }

    func test_persistsLanguageCode() {
        let backing = MemoryStore()
        let s = SettingsStore(store: backing)
        s.languageCode = "en-US"
        XCTAssertEqual(SettingsStore(store: backing).languageCode, "en-US")
    }

    func test_persistsHotKeyIdentifier() {
        let backing = MemoryStore()
        let s = SettingsStore(store: backing)
        s.hotKeyIdentifier = "fn"
        XCTAssertEqual(SettingsStore(store: backing).hotKeyIdentifier, "fn")
    }
}
