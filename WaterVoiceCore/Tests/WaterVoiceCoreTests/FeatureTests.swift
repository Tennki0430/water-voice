import Testing
@testable import WaterVoiceCore

// MARK: - Tone

@Test("asIs tone adds no instruction line")
func asIsToneHasNoLine() {
    #expect(DictationTone.asIs.instructionLine == nil)
}

@Test("non-default tones provide an instruction line")
func tonesHaveLines() {
    #expect(DictationTone.formal.instructionLine != nil)
    #expect(DictationTone.email.instructionLine != nil)
}

// MARK: - Custom dictionary

@Test("dictionary filters unusable entries and builds a line")
func dictionaryBuildsLine() {
    let dict = CustomDictionary(entries: [
        DictionaryEntry(spoken: "さいとう", written: "齋藤"),
        DictionaryEntry(spoken: "  ", written: "空"), // unusable
    ])
    #expect(dict.entries.count == 1)
    let line = dict.instructionLine
    #expect(line?.contains("齋藤") == true)
    #expect(line?.contains("さいとう") == true)
}

@Test("empty dictionary has no line")
func emptyDictionaryNoLine() {
    #expect(CustomDictionary(entries: []).instructionLine == nil)
}

// MARK: - Voice command parser

@Test("parses trailing English translate command and strips it")
func parsesTranslate() {
    let parser = VoiceCommandParser()
    let result = parser.parse("明日の会議の件です 英語にして")
    #expect(result.command == .translate(language: "英語"))
    #expect(result.body == "明日の会議の件です")
}

@Test("longer phrase wins over shorter prefix")
func longestMatchWins() {
    let parser = VoiceCommandParser()
    let result = parser.parse("これを英語に翻訳して")
    #expect(result.command == .translate(language: "英語"))
    #expect(result.body == "これを")
}

@Test("bullet and summarize commands parse")
func parsesBulletAndSummary() {
    let parser = VoiceCommandParser()
    #expect(parser.parse("ABCの三点 箇条書きにして").command == .bulletList)
    #expect(parser.parse("長い議事録の本文 要約して").command == .summarize)
}

@Test("no command leaves text untouched")
func noCommand() {
    let parser = VoiceCommandParser()
    let result = parser.parse("普通の文章です")
    #expect(result.command == nil)
    #expect(result.body == "普通の文章です")
}

@Test("command phrase with no body is not treated as a command")
func commandOnlyIgnored() {
    let parser = VoiceCommandParser()
    let result = parser.parse("英語にして")
    #expect(result.command == nil)
}

// MARK: - App profile resolver

@Test("resolver returns per-app tone, falls back to default")
func profileResolution() {
    let resolver = AppProfileResolver(
        defaultTone: .casual,
        profiles: ["com.tinyspeck.slackmacgap": .chat, "com.apple.mail": .email]
    )
    #expect(resolver.tone(forBundleID: "com.apple.mail") == .email)
    #expect(resolver.tone(forBundleID: "com.unknown.app") == .casual)
    #expect(resolver.tone(forBundleID: nil) == .casual)
}

// MARK: - Prompt composition

@Test("instructions(context:) includes tone, dictionary, and command lines")
func promptComposition() {
    let prompt = FormatterPrompt()
    let context = FormatterContext(
        tone: .formal,
        dictionary: CustomDictionary(entries: [DictionaryEntry(spoken: "さいとう", written: "齋藤")]),
        command: .bulletList
    )
    let text = prompt.instructions(context: context)
    #expect(text.contains("です・ます"))
    #expect(text.contains("齋藤"))
    #expect(text.contains("箇条書き"))
    #expect(text.contains("最優先の指示"))
}

@Test("plain context yields only base instructions")
func plainContext() {
    let prompt = FormatterPrompt()
    let text = prompt.instructions(context: .plain)
    #expect(!text.contains("追加ルール"))
    #expect(!text.contains("最優先の指示"))
}

// MARK: - SettingsStore persistence

private final class MemoryStore: KeyValueStore {
    private var values: [String: String] = [:]
    func string(forKey key: String) -> String? { values[key] }
    func set(_ value: String?, forKey key: String) { values[key] = value }
}

@Test("settings persist tone, dictionary, and app profiles via JSON")
func settingsRoundTrip() {
    let settings = SettingsStore(store: MemoryStore())
    #expect(settings.defaultTone == .asIs)

    settings.defaultTone = .email
    settings.dictionaryEntries = [DictionaryEntry(spoken: "あくあ", written: "Aqua")]
    settings.appProfiles = ["com.apple.mail": .email]

    #expect(settings.defaultTone == .email)
    #expect(settings.dictionaryEntries.first?.written == "Aqua")
    #expect(settings.profileResolver.tone(forBundleID: "com.apple.mail") == .email)
}
