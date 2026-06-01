import XCTest
@testable import WaterVoiceCore

final class FormatterPromptTests: XCTestCase {
    func test_instructions_mentionCleanupRules() {
        let p = FormatterPrompt()
        let instructions = p.instructions
        XCTAssertTrue(instructions.contains("句読点"))
        XCTAssertTrue(instructions.contains("フィラー"))
    }

    func test_prompt_wrapsRawTextVerbatim() {
        let p = FormatterPrompt()
        let prompt = p.prompt(rawText: "えーと今日は晴れです")
        XCTAssertTrue(prompt.contains("えーと今日は晴れです"))
    }

    func test_isWithinTokenBudget_trueForShortText() {
        let p = FormatterPrompt()
        XCTAssertTrue(p.isWithinTokenBudget(rawText: "短い文章"))
    }

    func test_isWithinTokenBudget_falseForHugeText() {
        let p = FormatterPrompt()
        let huge = String(repeating: "あ", count: 20_000)
        XCTAssertFalse(p.isWithinTokenBudget(rawText: huge))
    }
}
