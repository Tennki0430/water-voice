import XCTest
@testable import WaterVoiceCore

final class ClipboardLogicTests: XCTestCase {
    final class FakeClipboard: ClipboardAccessing, @unchecked Sendable {
        var contents: String?
        var pasteCount = 0
        var history: [String?] = []
        func read() -> String? { contents }
        func write(_ text: String?) { contents = text; history.append(text) }
        func sendPaste() { pasteCount += 1; history.append("PASTE:\(contents ?? "nil")") }
    }

    func test_inject_pastesNewTextThenRestoresOriginal() async throws {
        let clip = FakeClipboard()
        clip.contents = "original"
        let logic = ClipboardLogic(clipboard: clip, restoreDelayNanos: 0)

        try await logic.inject(text: "formatted result")

        XCTAssertEqual(clip.contents, "original")
        XCTAssertEqual(clip.pasteCount, 1)
    }

    func test_inject_pastesTheNewTextNotTheOriginal() async throws {
        let clip = FakeClipboard()
        clip.contents = "original"
        let logic = ClipboardLogic(clipboard: clip, restoreDelayNanos: 0)

        try await logic.inject(text: "formatted result")

        XCTAssertTrue(clip.history.contains("PASTE:formatted result"))
    }

    func test_inject_handlesEmptyOriginalClipboard() async throws {
        let clip = FakeClipboard()
        clip.contents = nil
        let logic = ClipboardLogic(clipboard: clip, restoreDelayNanos: 0)

        try await logic.inject(text: "hello")

        XCTAssertNil(clip.contents)
        XCTAssertEqual(clip.pasteCount, 1)
    }
}
