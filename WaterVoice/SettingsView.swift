import SwiftUI
import WaterVoiceCore

/// Settings window modeled on Aqua Voice: shortcut, language, custom instructions, dictionary.
/// Persists via SettingsStore (UserDefaults-backed).
struct SettingsView: View {
    @State private var languageCode: String
    @State private var customPrompt: String
    @State private var dictionary: String

    private let store: SettingsStore

    init() {
        let store = SettingsStore(store: UserDefaultsKeyValueStore())
        self.store = store
        _languageCode = State(initialValue: store.languageCode)
        _customPrompt = State(initialValue: store.customPrompt ?? "")
        _dictionary = State(initialValue: UserDefaults.standard.string(forKey: "watervoice.dictionary") ?? "")
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("一般", systemImage: "gearshape") }
            instructionsTab
                .tabItem { Label("カスタム指示", systemImage: "text.badge.star") }
            dictionaryTab
                .tabItem { Label("辞書", systemImage: "character.book.closed") }
        }
        .frame(width: 480, height: 380)
        .padding()
    }

    private var generalTab: some View {
        Form {
            LabeledContent("ショートカット") {
                Text("右 Option を押しながら話す")
                    .foregroundStyle(.secondary)
            }
            Picker("言語", selection: $languageCode) {
                Text("日本語").tag("ja-JP")
                Text("English (US)").tag("en-US")
            }
            .onChange(of: languageCode) { _, newValue in
                store.languageCode = newValue
            }
            Text("※ ショートカットの変更は今後のバージョンで対応予定です。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var instructionsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("整形のカスタム指示")
                .font(.headline)
            Text("文字起こし結果をどう整えるかの指示。空欄なら既定のルール（句読点付け・フィラー除去）を使います。")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $customPrompt)
                .font(.body)
                .border(.quaternary)
                .onChange(of: customPrompt) { _, newValue in
                    store.customPrompt = newValue.isEmpty ? nil : newValue
                }
        }
    }

    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カスタム辞書")
                .font(.headline)
            Text("1行に1語。固有名詞や専門用語を登録すると認識精度が上がります（今後反映予定）。")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $dictionary)
                .font(.body)
                .border(.quaternary)
                .onChange(of: dictionary) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "watervoice.dictionary")
                }
        }
    }
}

/// Placeholder statistics window (Aqua Voice shows time saved, word counts, etc.).
struct StatsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("統計情報")
                .font(.headline)
            Text("入力文字数や短縮できた時間などを表示する予定です。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(width: 360, height: 220)
    }
}
