import SwiftUI
import WaterVoiceCore

/// Settings window: shortcut, language, tone, dictionary, per-app profiles.
/// Persists via SettingsStore (UserDefaults-backed).
struct SettingsView: View {
    @State private var languageCode: String
    @State private var defaultTone: DictationTone
    @State private var dictionary: [DictionaryEntry]
    @State private var profiles: [AppProfileRow]
    @State private var formatterEngine: FormatterEngine
    @State private var geminiApiKey: String
    @State private var claudeApiKey: String
    @State private var geminiModel: String
    @State private var claudeModel: String

    private let store: SettingsStore

    init() {
        let store = SettingsStore(store: UserDefaultsKeyValueStore())
        self.store = store
        _languageCode = State(initialValue: store.languageCode)
        _defaultTone = State(initialValue: store.defaultTone)
        _dictionary = State(initialValue: store.dictionaryEntries)
        _profiles = State(initialValue: store.appProfiles.map { AppProfileRow(bundleID: $0.key, tone: $0.value) })
        _formatterEngine = State(initialValue: store.formatterEngine)
        _geminiApiKey = State(initialValue: store.geminiApiKey ?? "")
        _claudeApiKey = State(initialValue: store.claudeApiKey ?? "")
        _geminiModel = State(initialValue: store.geminiModel)
        _claudeModel = State(initialValue: store.claudeModel)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("一般", systemImage: "gearshape") }
            aiEngineTab
                .tabItem { Label("AI整形", systemImage: "sparkles") }
            dictionaryTab
                .tabItem { Label("辞書", systemImage: "character.book.closed") }
            profilesTab
                .tabItem { Label("アプリ別", systemImage: "app.badge") }
            commandsTab
                .tabItem { Label("AIコマンド", systemImage: "wand.and.stars") }
        }
        .frame(width: 520, height: 460)
        .padding()
    }

    // MARK: - 一般（言語＋既定トーン）

    private var generalTab: some View {
        Form {
            LabeledContent("ショートカット") {
                Text("右 Option を押しながら話す").foregroundStyle(.secondary)
            }
            Picker("言語", selection: $languageCode) {
                Text("日本語").tag("ja-JP")
                Text("English (US)").tag("en-US")
            }
            .onChange(of: languageCode) { _, newValue in store.languageCode = newValue }

            Picker("既定のトーン", selection: $defaultTone) {
                ForEach(DictationTone.allCases, id: \.self) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
            .onChange(of: defaultTone) { _, newValue in store.defaultTone = newValue }

            Text("トーンは整形時の文体です。アプリ別タブで個別に上書きできます。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    // MARK: - AI整形エンジン

    private var aiEngineTab: some View {
        Form {
            Picker("整形エンジン", selection: $formatterEngine) {
                ForEach(FormatterEngine.allCases, id: \.self) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }
            .onChange(of: formatterEngine) { _, newValue in store.formatterEngine = newValue }

            Text("オンデバイス: Apple Intelligence（macOS 26）または Ollama（ローカル）を使用。\nAPI: 指定したサービスのクラウド API を使用します（API キーが必要）。")
                .font(.caption).foregroundStyle(.secondary)

            if formatterEngine == .gemini {
                Section("Gemini API") {
                    SecureField("Gemini API キー", text: $geminiApiKey)
                        .onChange(of: geminiApiKey) { _, v in store.geminiApiKey = v.isEmpty ? nil : v }
                    Picker("モデル", selection: $geminiModel) {
                        ForEach(GeminiModel.all) { m in
                            Text(m.displayName).tag(m.id)
                        }
                    }
                    .onChange(of: geminiModel) { _, v in store.geminiModel = v }
                    Text("APIキーは aistudio.google.com で取得できます。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if formatterEngine == .claude {
                Section("Claude API") {
                    SecureField("Claude API キー", text: $claudeApiKey)
                        .onChange(of: claudeApiKey) { _, v in store.claudeApiKey = v.isEmpty ? nil : v }
                    Picker("モデル", selection: $claudeModel) {
                        ForEach(ClaudeModel.all) { m in
                            Text(m.displayName).tag(m.id)
                        }
                    }
                    .onChange(of: claudeModel) { _, v in store.claudeModel = v }
                    Text("APIキーは console.anthropic.com で取得できます。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if formatterEngine != .auto {
                Text("⚠️ APIキー未入力の場合はオンデバイスにフォールバックします。")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - カスタム辞書（読み → 表記）

    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カスタム辞書").font(.headline)
            Text("「読み（聞こえ方）」と「正しい表記」を登録すると、固有名詞や専門用語の誤変換を防げます。")
                .font(.caption).foregroundStyle(.secondary)

            List {
                ForEach($dictionary) { $entry in
                    HStack {
                        TextField("読み（例: さいとう）", text: $entry.spoken)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        TextField("表記（例: 齋藤）", text: $entry.written)
                    }
                }
                .onDelete { dictionary.remove(atOffsets: $0); persistDictionary() }
            }
            .onChange(of: dictionary) { _, _ in persistDictionary() }

            Button {
                dictionary.append(DictionaryEntry(spoken: "", written: ""))
            } label: { Label("追加", systemImage: "plus") }
        }
    }

    private func persistDictionary() {
        store.dictionaryEntries = dictionary.filter(\.isUsable)
    }

    // MARK: - アプリ別プロファイル

    private var profilesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("アプリ別プロファイル").font(.headline)
            Text("特定アプリが最前面のとき、トーンを自動で切り替えます。バンドルID（例: com.apple.mail）で指定します。")
                .font(.caption).foregroundStyle(.secondary)

            List {
                ForEach($profiles) { $row in
                    HStack {
                        TextField("バンドルID", text: $row.bundleID)
                        Picker("", selection: $row.tone) {
                            ForEach(DictationTone.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                    }
                }
                .onDelete { profiles.remove(atOffsets: $0); persistProfiles() }
            }
            .onChange(of: profiles) { _, _ in persistProfiles() }

            Button {
                profiles.append(AppProfileRow(bundleID: "", tone: .formal))
            } label: { Label("追加", systemImage: "plus") }
        }
    }

    private func persistProfiles() {
        let valid = profiles.filter { !$0.bundleID.trimmingCharacters(in: .whitespaces).isEmpty }
        store.appProfiles = Dictionary(valid.map { ($0.bundleID, $0.tone) }) { first, _ in first }
    }

    // MARK: - AIコマンド説明

    private var commandsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIコマンド").font(.headline)
            Text("話し終わりに以下の言葉を付けると、その指示どおりに整形します（完全オンデバイス）。")
                .font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                commandRow("…英語にして / 英語に翻訳して", "英語に翻訳")
                commandRow("…日本語にして", "日本語に翻訳")
                commandRow("…箇条書きにして", "箇条書きに整理")
                commandRow("…要約して", "要点を要約")
                commandRow("…敬語にして / 丁寧にして", "敬語に書き換え")
            }
            Spacer()
        }
        .padding(4)
    }

    private func commandRow(_ phrase: String, _ effect: String) -> some View {
        HStack {
            Text(phrase).font(.system(.body, design: .monospaced))
            Spacer()
            Text(effect).foregroundStyle(.secondary)
        }
    }
}

/// Editable row for the per-app profiles table.
private struct AppProfileRow: Identifiable, Equatable {
    let id = UUID()
    var bundleID: String
    var tone: DictationTone
}

/// 統計情報ウィンドウ
struct StatsView: View {
    @StateObject private var stats = StatsTracker()

    var body: some View {
        VStack(spacing: 24) {
            Text("統計情報")
                .font(.title2).bold()

            HStack(spacing: 32) {
                StatCard(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    title: "今日の節約時間",
                    value: formatMinutes(stats.savedMinutesToday),
                    subtitle: "\(stats.todayChars) 文字"
                )
                StatCard(
                    icon: "chart.bar.fill",
                    title: "合計節約時間",
                    value: formatMinutes(stats.savedMinutesTotal),
                    subtitle: "\(stats.totalChars) 文字 / \(stats.totalSessions) 回"
                )
            }

            Text("タイピング速度 300文字/分 との比較で算出しています。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 420, height: 240)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 1 { return "< 1分" }
        if minutes < 60 { return String(format: "%.0f分", minutes) }
        return String(format: "%.1f時間", minutes / 60)
    }
}

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(title)
                .font(.callout).bold()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
    }
}
