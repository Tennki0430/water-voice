import Testing
@testable import WaterVoiceCore

// MARK: - RuleBasedFormatter

@Test("rule-based formatter removes fillers and adds punctuation")
func ruleBasedCleansFillers() async throws {
    let f = RuleBasedFormatter()
    let out = try await f.format(rawText: "えーと今日はあのー会議です")
    #expect(!out.contains("えーと"))
    #expect(!out.contains("あのー"))
    #expect(out.hasSuffix("。"))
}

@Test("rule-based formatter applies custom dictionary replacements")
func ruleBasedDictionary() {
    let f = RuleBasedFormatter()
    let dict = CustomDictionary(entries: [DictionaryEntry(spoken: "すいふと", written: "Swift")])
    let out = f.clean("すいふとは速い", dictionary: dict)
    #expect(out.contains("Swift"))
    #expect(!out.contains("すいふと"))
}

@Test("rule-based formatter does not double-add punctuation")
func ruleBasedNoDoublePunct() {
    let f = RuleBasedFormatter()
    let out = f.clean("これは完成です。", dictionary: CustomDictionary(entries: []))
    #expect(out == "これは完成です。")
}

// MARK: - FallbackFormatter

private struct AlwaysFails: Formatting {
    func format(rawText: String) async throws -> String {
        throw FormatterUnavailable(reason: "test")
    }
}

private struct EchoUpper: Formatting {
    func format(rawText: String) async throws -> String { rawText + "!" }
}

@Test("fallback uses first succeeding primary")
func fallbackUsesPrimary() async throws {
    let f = FallbackFormatter(primaries: [AlwaysFails(), EchoUpper()], fallback: RuleBasedFormatter())
    let out = try await f.format(rawText: "test")
    #expect(out == "test!")
}

@Test("fallback uses rule-based when all primaries fail")
func fallbackUsesRuleBased() async throws {
    let f = FallbackFormatter(primaries: [AlwaysFails()], fallback: RuleBasedFormatter())
    let out = try await f.format(rawText: "えーとテスト")
    #expect(!out.contains("えーと"))
    #expect(out.hasSuffix("。"))
}
