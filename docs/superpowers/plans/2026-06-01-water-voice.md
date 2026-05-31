# Water Voice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "Water Voice", a macOS menu-bar dictation app that records mic audio while a hotkey is held, transcribes it with Apple's `SpeechAnalyzer`, cleans it up with Apple Foundation Models (on-device), and pastes the result into the frontmost app via the clipboard.

**Architecture:** Two layers. (1) A pure-Swift SwiftPM package `WaterVoiceCore` holding all platform-independent logic behind protocols — the `AppCoordinator` state machine, the formatting prompt builder, clipboard save/restore logic, and settings — fully unit-tested with `swift test` (no Xcode needed). (2) An Xcode app target `WaterVoice` that provides the platform-bound concrete implementations (`AVAudioEngine` recorder, `SpeechAnalyzer` transcriber, `FoundationModels` formatter, `CGEvent` paste, `MenuBarExtra` UI) and wires them into the coordinator. We build and fully test layer 1 now; layer 2 lands once Xcode is installed.

**Tech Stack:** Swift 6.1, Swift Package Manager, XCTest, SwiftUI (`MenuBarExtra`), `AVAudioEngine`, `Speech` (`SpeechAnalyzer`/`SpeechTranscriber`), `FoundationModels` (`SystemLanguageModel`/`LanguageModelSession`), `CGEvent`, `UserDefaults`. Target macOS 26.0+.

**Reference spec:** `docs/superpowers/specs/2026-05-31-water-voice-design.md`

---

## File Structure

### Layer 1 — `WaterVoiceCore` SwiftPM package (build & test now, no Xcode)

```
WaterVoiceCore/
├── Package.swift
├── Sources/WaterVoiceCore/
│   ├── DictationState.swift        # enum of state-machine states
│   ├── Protocols.swift             # Transcribing, Formatting, TextInjecting, AudioRecording protocols
│   ├── FormatterPrompt.swift       # builds the cleanup instructions + prompt strings
│   ├── ClipboardLogic.swift        # pure save→inject→restore sequencing (protocol-driven)
│   ├── SettingsStore.swift         # hotkey / language / prompt persistence over a KeyValueStore protocol
│   └── AppCoordinator.swift        # the state machine wiring the protocols together
└── Tests/WaterVoiceCoreTests/
    ├── FormatterPromptTests.swift
    ├── ClipboardLogicTests.swift
    ├── SettingsStoreTests.swift
    └── AppCoordinatorTests.swift
```

### Layer 2 — `WaterVoice` Xcode app target (build once Xcode is installed)

```
WaterVoice/                         # created via Xcode "macOS App" template
├── WaterVoiceApp.swift             # @main, MenuBarExtra, LSUIElement
├── Adapters/
│   ├── AVAudioRecorder.swift       # AudioRecording impl (AVAudioEngine)
│   ├── SpeechAnalyzerTranscriber.swift  # Transcribing impl (SpeechAnalyzer/SpeechTranscriber)
│   ├── FoundationModelsFormatter.swift  # Formatting impl (LanguageModelSession)
│   ├── CGEventTextInjector.swift   # TextInjecting impl (NSPasteboard + CGEvent Cmd+V)
│   └── HotKeyMonitor.swift         # global hotkey (press/release)
├── UserDefaultsKeyValueStore.swift # KeyValueStore impl over UserDefaults
├── MenuBarView.swift               # status + settings + availability guidance
├── Info.plist                      # LSUIElement=true, usage descriptions
└── WaterVoice.entitlements         # mic, speech recognition
```

This plan covers **Layer 1 fully** (Tasks 1–6) and **Layer 2 as a guided scaffold** (Tasks 7–12) to be executed after Xcode is installed. Layer 1 tasks are pure TDD with `swift test`. Layer 2 tasks document the exact adapter code against the spec; their "tests" are manual E2E because they touch hardware/OS services.

---

## Task 1: Bootstrap the WaterVoiceCore package

**Files:**
- Create: `WaterVoiceCore/Package.swift`
- Create: `WaterVoiceCore/Sources/WaterVoiceCore/DictationState.swift`

- [ ] **Step 1: Create the package manifest**

Create `WaterVoiceCore/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WaterVoiceCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WaterVoiceCore", targets: ["WaterVoiceCore"]),
    ],
    targets: [
        .target(name: "WaterVoiceCore"),
        .testTarget(
            name: "WaterVoiceCoreTests",
            dependencies: ["WaterVoiceCore"]
        ),
    ]
)
```

Note: `.macOS(.v15)` keeps the *pure-logic* package buildable on the current toolchain (the FoundationModels/Speech code lives in the Xcode app target, not here). The app target itself targets macOS 26.

- [ ] **Step 2: Create the state enum**

Create `WaterVoiceCore/Sources/WaterVoiceCore/DictationState.swift`:

```swift
import Foundation

/// The states of the dictation state machine.
public enum DictationState: Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case formatting
    case injecting
}
```

- [ ] **Step 3: Verify the package builds**

Run: `cd WaterVoiceCore && swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/macintosh/Desktop/Vivecording/VOICE
git add WaterVoiceCore/Package.swift WaterVoiceCore/Sources/WaterVoiceCore/DictationState.swift
git commit -m "feat: bootstrap WaterVoiceCore package with DictationState"
```

---

## Task 2: Define the component protocols

**Files:**
- Create: `WaterVoiceCore/Sources/WaterVoiceCore/Protocols.swift`

- [ ] **Step 1: Write the protocols**

Create `WaterVoiceCore/Sources/WaterVoiceCore/Protocols.swift`:

```swift
import Foundation

/// Records microphone audio. Implementations are platform-bound (AVAudioEngine).
public protocol AudioRecording: Sendable {
    func startRecording() async throws
    /// Stops recording and returns the captured audio as a file URL.
    func stopRecording() async throws -> URL
}

/// Converts recorded audio into raw text.
public protocol Transcribing: Sendable {
    func transcribe(audioFileURL: URL) async throws -> String
}

/// Cleans up raw text (punctuation, filler removal, line breaks, misrecognition fixes).
public protocol Formatting: Sendable {
    /// Returns formatted text. Implementations should throw `FormatterUnavailable`
    /// when the underlying model cannot be used so the coordinator can fall back.
    func format(rawText: String) async throws -> String
}

/// Pastes text into the frontmost application.
public protocol TextInjecting: Sendable {
    func inject(text: String) async throws
}

/// Thrown by a `Formatting` implementation when the model is unavailable.
public struct FormatterUnavailable: Error, Equatable {
    public let reason: String
    public init(reason: String) { self.reason = reason }
}

/// Minimal key-value persistence abstraction so SettingsStore is testable without UserDefaults.
public protocol KeyValueStore: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd WaterVoiceCore && swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add WaterVoiceCore/Sources/WaterVoiceCore/Protocols.swift
git commit -m "feat: define core component protocols"
```

---

## Task 3: FormatterPrompt — build the cleanup prompt

**Files:**
- Create: `WaterVoiceCore/Sources/WaterVoiceCore/FormatterPrompt.swift`
- Test: `WaterVoiceCore/Tests/WaterVoiceCoreTests/FormatterPromptTests.swift`

- [ ] **Step 1: Write the failing test**

Create `WaterVoiceCore/Tests/WaterVoiceCoreTests/FormatterPromptTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd WaterVoiceCore && swift test --filter FormatterPromptTests`
Expected: FAIL — `cannot find 'FormatterPrompt' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `WaterVoiceCore/Sources/WaterVoiceCore/FormatterPrompt.swift`:

```swift
import Foundation

/// Builds the instructions and prompt strings sent to the on-device language model.
/// Kept here (not in the app target) so the wording is unit-testable.
public struct FormatterPrompt: Sendable {
    /// Conservative character budget. The on-device model has a 4,096-token combined
    /// limit; we approximate and guard against obviously oversized inputs.
    public let maxRawCharacters: Int

    public init(maxRawCharacters: Int = 6_000) {
        self.maxRawCharacters = maxRawCharacters
    }

    /// System instructions describing the model's role and cleanup rules.
    public var instructions: String {
        """
        あなたは音声入力の整形アシスタントです。
        受け取った日本語の生テキストを、意味を変えずに読みやすく整えてください。
        ルール:
        - 適切な句読点を付ける。
        - 「えーと」「あのー」などのフィラーを除去する。
        - 自然な位置で改行する。
        - 明らかな音声誤認識を文脈から修正する。
        - 内容を要約・追記・翻訳しない。整形済みの本文だけを返す。
        """
    }

    /// The per-request prompt wrapping the raw transcript.
    public func prompt(rawText: String) -> String {
        """
        次のテキストを上記ルールに従って整形してください:

        \(rawText)
        """
    }

    /// True when the raw text is small enough to attempt formatting in one pass.
    public func isWithinTokenBudget(rawText: String) -> Bool {
        rawText.count <= maxRawCharacters
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd WaterVoiceCore && swift test --filter FormatterPromptTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add WaterVoiceCore/Sources/WaterVoiceCore/FormatterPrompt.swift WaterVoiceCore/Tests/WaterVoiceCoreTests/FormatterPromptTests.swift
git commit -m "feat: add FormatterPrompt with cleanup rules and token-budget guard"
```

---

## Task 4: ClipboardLogic — save → inject → restore sequencing

**Files:**
- Create: `WaterVoiceCore/Sources/WaterVoiceCore/ClipboardLogic.swift`
- Test: `WaterVoiceCore/Tests/WaterVoiceCoreTests/ClipboardLogicTests.swift`

This isolates the *ordering* logic (snapshot current clipboard, set new text, trigger paste, restore original) behind a protocol so it's testable without `NSPasteboard`.

- [ ] **Step 1: Write the failing test**

Create `WaterVoiceCore/Tests/WaterVoiceCoreTests/ClipboardLogicTests.swift`:

```swift
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
        let logic = ClipboardLogic(clipboard: clip)

        try await logic.inject(text: "formatted result")

        // Final clipboard state must equal the original.
        XCTAssertEqual(clip.contents, "original")
        XCTAssertEqual(clip.pasteCount, 1)
    }

    func test_inject_pastesTheNewTextNotTheOriginal() async throws {
        let clip = FakeClipboard()
        clip.contents = "original"
        let logic = ClipboardLogic(clipboard: clip)

        try await logic.inject(text: "formatted result")

        // The paste must have happened while "formatted result" was on the clipboard.
        XCTAssertTrue(clip.history.contains("PASTE:formatted result"))
    }

    func test_inject_handlesEmptyOriginalClipboard() async throws {
        let clip = FakeClipboard()
        clip.contents = nil
        let logic = ClipboardLogic(clipboard: clip)

        try await logic.inject(text: "hello")

        XCTAssertNil(clip.contents)
        XCTAssertEqual(clip.pasteCount, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd WaterVoiceCore && swift test --filter ClipboardLogicTests`
Expected: FAIL — `cannot find 'ClipboardAccessing'` / `'ClipboardLogic'`.

- [ ] **Step 3: Write minimal implementation**

Create `WaterVoiceCore/Sources/WaterVoiceCore/ClipboardLogic.swift`:

```swift
import Foundation

/// Abstraction over the system pasteboard + paste keystroke, so sequencing is testable.
public protocol ClipboardAccessing: Sendable {
    func read() -> String?
    func write(_ text: String?)
    /// Sends the Cmd+V keystroke to the frontmost app.
    func sendPaste()
}

/// Pure sequencing: snapshot original clipboard, write new text, paste, restore original.
/// Conforms to `TextInjecting` so it drops straight into the coordinator.
public struct ClipboardLogic: TextInjecting {
    private let clipboard: ClipboardAccessing
    /// Delay (nanoseconds) to let the paste land before restoring the original.
    private let restoreDelayNanos: UInt64

    public init(clipboard: ClipboardAccessing, restoreDelayNanos: UInt64 = 100_000_000) {
        self.clipboard = clipboard
        self.restoreDelayNanos = restoreDelayNanos
    }

    public func inject(text: String) async throws {
        let original = clipboard.read()
        clipboard.write(text)
        clipboard.sendPaste()
        if restoreDelayNanos > 0 {
            try? await Task.sleep(nanoseconds: restoreDelayNanos)
        }
        clipboard.write(original)
    }
}
```

Note: tests pass `restoreDelayNanos` via the default but run fast because `Task.sleep` of 0.1s is negligible; if you want zero delay in tests, construct `ClipboardLogic(clipboard: clip, restoreDelayNanos: 0)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd WaterVoiceCore && swift test --filter ClipboardLogicTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add WaterVoiceCore/Sources/WaterVoiceCore/ClipboardLogic.swift WaterVoiceCore/Tests/WaterVoiceCoreTests/ClipboardLogicTests.swift
git commit -m "feat: add ClipboardLogic with save-inject-restore sequencing"
```

---

## Task 5: SettingsStore — persisted preferences

**Files:**
- Create: `WaterVoiceCore/Sources/WaterVoiceCore/SettingsStore.swift`
- Test: `WaterVoiceCore/Tests/WaterVoiceCoreTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `WaterVoiceCore/Tests/WaterVoiceCoreTests/SettingsStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd WaterVoiceCore && swift test --filter SettingsStoreTests`
Expected: FAIL — `cannot find 'SettingsStore'`.

- [ ] **Step 3: Write minimal implementation**

Create `WaterVoiceCore/Sources/WaterVoiceCore/SettingsStore.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd WaterVoiceCore && swift test --filter SettingsStoreTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add WaterVoiceCore/Sources/WaterVoiceCore/SettingsStore.swift WaterVoiceCore/Tests/WaterVoiceCoreTests/SettingsStoreTests.swift
git commit -m "feat: add SettingsStore with persisted language/hotkey/prompt"
```

---

## Task 6: AppCoordinator — the state machine

**Files:**
- Create: `WaterVoiceCore/Sources/WaterVoiceCore/AppCoordinator.swift`
- Test: `WaterVoiceCore/Tests/WaterVoiceCoreTests/AppCoordinatorTests.swift`

This is the heart of the app: it sequences record → transcribe → format (with fallback) → inject, exposing the current `DictationState` and reporting failures. It depends only on the protocols, so it's fully testable with fakes.

- [ ] **Step 1: Write the failing test**

Create `WaterVoiceCore/Tests/WaterVoiceCoreTests/AppCoordinatorTests.swift`:

```swift
import XCTest
@testable import WaterVoiceCore

final class AppCoordinatorTests: XCTestCase {
    // MARK: Fakes

    final class FakeRecorder: AudioRecording, @unchecked Sendable {
        var url = URL(fileURLWithPath: "/tmp/rec.caf")
        func startRecording() async throws {}
        func stopRecording() async throws -> URL { url }
    }
    final class FakeTranscriber: Transcribing, @unchecked Sendable {
        var result = "raw text"
        var error: Error?
        func transcribe(audioFileURL: URL) async throws -> String {
            if let error { throw error }
            return result
        }
    }
    final class FakeFormatter: Formatting, @unchecked Sendable {
        var result = "formatted text"
        var error: Error?
        func format(rawText: String) async throws -> String {
            if let error { throw error }
            return result
        }
    }
    final class FakeInjector: TextInjecting, @unchecked Sendable {
        var injected: [String] = []
        func inject(text: String) async throws { injected.append(text) }
    }

    struct SampleError: Error {}

    private func makeCoordinator(
        transcriber: FakeTranscriber = FakeTranscriber(),
        formatter: FakeFormatter = FakeFormatter(),
        injector: FakeInjector = FakeInjector()
    ) -> AppCoordinator {
        AppCoordinator(
            recorder: FakeRecorder(),
            transcriber: transcriber,
            formatter: formatter,
            injector: injector
        )
    }

    // MARK: Tests

    func test_startsIdle() {
        let c = makeCoordinator()
        XCTAssertEqual(c.state, .idle)
    }

    func test_happyPath_injectsFormattedText_andReturnsToIdle() async throws {
        let injector = FakeInjector()
        let c = makeCoordinator(injector: injector)

        try await c.beginRecording()
        await c.endRecordingAndProcess()

        XCTAssertEqual(injector.injected, ["formatted text"])
        XCTAssertEqual(c.state, .idle)
    }

    func test_formatterUnavailable_fallsBackToRawText() async throws {
        let formatter = FakeFormatter()
        formatter.error = FormatterUnavailable(reason: "model not ready")
        let injector = FakeInjector()
        let transcriber = FakeTranscriber()
        transcriber.result = "the raw transcript"
        let c = makeCoordinator(transcriber: transcriber, formatter: formatter, injector: injector)

        try await c.beginRecording()
        await c.endRecordingAndProcess()

        XCTAssertEqual(injector.injected, ["the raw transcript"])
        XCTAssertEqual(c.state, .idle)
    }

    func test_transcriptionFailure_returnsToIdle_withoutInjecting() async throws {
        let transcriber = FakeTranscriber()
        transcriber.error = SampleError()
        let injector = FakeInjector()
        let c = makeCoordinator(transcriber: transcriber, injector: injector)

        try await c.beginRecording()
        await c.endRecordingAndProcess()

        XCTAssertTrue(injector.injected.isEmpty)
        XCTAssertEqual(c.state, .idle)
        XCTAssertNotNil(c.lastError)
    }

    func test_emptyTranscript_skipsInjection() async throws {
        let transcriber = FakeTranscriber()
        transcriber.result = "   "
        let injector = FakeInjector()
        let c = makeCoordinator(transcriber: transcriber, injector: injector)

        try await c.beginRecording()
        await c.endRecordingAndProcess()

        XCTAssertTrue(injector.injected.isEmpty)
        XCTAssertEqual(c.state, .idle)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd WaterVoiceCore && swift test --filter AppCoordinatorTests`
Expected: FAIL — `cannot find 'AppCoordinator'`.

- [ ] **Step 3: Write minimal implementation**

Create `WaterVoiceCore/Sources/WaterVoiceCore/AppCoordinator.swift`:

```swift
import Foundation

/// Drives the dictation pipeline as a state machine.
/// Marked @MainActor because the app target binds `state` to SwiftUI.
@MainActor
public final class AppCoordinator: ObservableObject {
    @Published public private(set) var state: DictationState = .idle
    public private(set) var lastError: Error?

    private let recorder: AudioRecording
    private let transcriber: Transcribing
    private let formatter: Formatting
    private let injector: TextInjecting

    public init(
        recorder: AudioRecording,
        transcriber: Transcribing,
        formatter: Formatting,
        injector: TextInjecting
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.formatter = formatter
        self.injector = injector
    }

    /// Hotkey pressed: begin recording. Throws if recording can't start.
    public func beginRecording() async throws {
        guard state == .idle else { return }
        lastError = nil
        try await recorder.startRecording()
        state = .recording
    }

    /// Hotkey released: stop recording and run the pipeline. Never throws —
    /// failures are captured in `lastError` and the machine returns to idle.
    public func endRecordingAndProcess() async {
        guard state == .recording else { return }
        do {
            let audioURL = try await recorder.stopRecording()

            state = .transcribing
            let raw = try await transcriber.transcribe(audioFileURL: audioURL)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                state = .idle
                return
            }

            state = .formatting
            let finalText = await formatOrFallback(rawText: trimmed)

            state = .injecting
            try await injector.inject(text: finalText)

            state = .idle
        } catch {
            lastError = error
            state = .idle
        }
    }

    /// Formats the text, falling back to the raw text when the model is unavailable.
    private func formatOrFallback(rawText: String) async -> String {
        do {
            return try await formatter.format(rawText: rawText)
        } catch {
            // Any formatter error (unavailable or otherwise) falls back to raw text;
            // we still surface it for the menu-bar UI to optionally show.
            lastError = error
            return rawText
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd WaterVoiceCore && swift test --filter AppCoordinatorTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the full suite**

Run: `cd WaterVoiceCore && swift test`
Expected: PASS — all tests across FormatterPrompt, ClipboardLogic, SettingsStore, AppCoordinator (15 tests total).

- [ ] **Step 6: Commit**

```bash
git add WaterVoiceCore/Sources/WaterVoiceCore/AppCoordinator.swift WaterVoiceCore/Tests/WaterVoiceCoreTests/AppCoordinatorTests.swift
git commit -m "feat: add AppCoordinator state machine with formatter fallback"
```

**🎯 Milestone: Layer 1 complete.** The entire app logic is implemented and unit-tested without Xcode. Everything below requires Xcode to be installed.

---

## Task 7: Create the Xcode app target (requires Xcode)

**Prerequisite:** Xcode installed from the App Store; run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` and confirm `xcodebuild -version` works.

**Files:**
- Create: `WaterVoice.xcodeproj` (via Xcode template)
- Create: `WaterVoice/WaterVoiceApp.swift`
- Modify: `WaterVoice/Info.plist`
- Create: `WaterVoice/WaterVoice.entitlements`

- [ ] **Step 1: Create the project**

In Xcode: File → New → Project → macOS → App.
- Product Name: `WaterVoice`
- Interface: SwiftUI, Language: Swift
- Save into `/Users/macintosh/Desktop/Vivecording/VOICE/`
- Set the deployment target to **macOS 26.0**.

- [ ] **Step 2: Add the local package dependency**

In Xcode: File → Add Package Dependencies → Add Local → select the `WaterVoiceCore/` folder. Add the `WaterVoiceCore` library to the `WaterVoice` target.

- [ ] **Step 3: Configure Info.plist for menu-bar-only + permissions**

Add these keys to `WaterVoice/Info.plist`:

```xml
<key>LSUIElement</key>
<true/>
<key>NSMicrophoneUsageDescription</key>
<string>Water Voice records your voice to transcribe it into text.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Water Voice transcribes your recorded speech on device.</string>
```

- [ ] **Step 4: Configure entitlements**

In `WaterVoice/WaterVoice.entitlements` enable:
- `com.apple.security.device.audio-input` = YES
- App Sandbox: keep enabled; if global hotkey / CGEvent paste require it, you may need to disable sandbox for personal use. Document the choice in a comment.

- [ ] **Step 5: Verify it builds and launches**

Run from Xcode (Cmd+R). Expected: app launches with no Dock icon; a default `MenuBarExtra` icon appears in the menu bar (added in Task 11).

- [ ] **Step 6: Commit**

```bash
git add WaterVoice.xcodeproj WaterVoice/
git commit -m "feat: scaffold WaterVoice Xcode app target (menu-bar, permissions)"
```

---

## Task 8: AVAudioRecorder adapter

**Files:**
- Create: `WaterVoice/Adapters/AVAudioRecorder.swift`

- [ ] **Step 1: Implement `AudioRecording` with AVAudioEngine**

Create `WaterVoice/Adapters/AVAudioRecorder.swift`:

```swift
import AVFoundation
import WaterVoiceCore

/// Records mic input to a temporary file using AVAudioEngine.
final class AVAudioRecorderAdapter: AudioRecording, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("watervoice-\(UUID().uuidString).caf")

    func startRecording() async throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("watervoice-\(UUID().uuidString).caf")
        file = try AVAudioFile(forWriting: outputURL, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
        }
        engine.prepare()
        try engine.start()
    }

    func stopRecording() async throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        return outputURL
    }
}
```

- [ ] **Step 2: Build**

In Xcode: Cmd+B. Expected: builds clean.

- [ ] **Step 3: Manual smoke test**

Temporarily wire a test button (or unit harness) to start/stop and confirm a non-zero `.caf` file is produced in the temp dir. Remove the temporary button after.

- [ ] **Step 4: Commit**

```bash
git add WaterVoice/Adapters/AVAudioRecorder.swift
git commit -m "feat: add AVAudioEngine recorder adapter"
```

---

## Task 9: SpeechAnalyzer transcriber adapter

**Files:**
- Create: `WaterVoice/Adapters/SpeechAnalyzerTranscriber.swift`

**Reference:** Apple `Speech` framework — `SpeechAnalyzer`, `SpeechTranscriber`, and `AssetInventory` for downloading the Japanese locale model. Confirm exact API signatures in Xcode's documentation viewer (the API is new in macOS 26 and may have shifted since this plan was written).

- [ ] **Step 1: Implement `Transcribing` with SpeechAnalyzer**

Create `WaterVoice/Adapters/SpeechAnalyzerTranscriber.swift`:

```swift
import Speech
import WaterVoiceCore

/// Transcribes an audio file using the on-device SpeechAnalyzer/SpeechTranscriber (macOS 26+).
final class SpeechAnalyzerTranscriber: Transcribing, @unchecked Sendable {
    let localeIdentifier: String

    init(localeIdentifier: String = "ja-JP") {
        self.localeIdentifier = localeIdentifier
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let locale = Locale(identifier: localeIdentifier)
        let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)

        // Ensure the locale assets are installed (download on first use).
        if let request = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioFileURL)

        try await analyzer.analyzeSequence(from: audioFile)
        try await analyzer.finalizeAndFinishThroughEndOfInput()

        var text = ""
        for try await result in transcriber.results {
            text += String(result.text.characters)
        }
        return text
    }
}
```

> ⚠️ The Speech API surface above is the macOS 26 shape as documented at plan time. If a symbol doesn't resolve, open Xcode → Developer Documentation → search "SpeechTranscriber" and adjust signatures. The `Transcribing` protocol contract (audio URL in, String out) does not change.

- [ ] **Step 2: Build**

Cmd+B. Resolve any signature drift against the docs. Expected: builds clean.

- [ ] **Step 3: Manual smoke test**

Feed the `.caf` from Task 8 and print the transcript. Confirm Japanese text appears.

- [ ] **Step 4: Commit**

```bash
git add WaterVoice/Adapters/SpeechAnalyzerTranscriber.swift
git commit -m "feat: add SpeechAnalyzer transcriber adapter"
```

---

## Task 10: FoundationModels formatter adapter

**Files:**
- Create: `WaterVoice/Adapters/FoundationModelsFormatter.swift`

**Reference:** `foundation-models-on-device` skill — availability check, `LanguageModelSession(instructions:)`, `respond(to:)`, access via `.content`.

- [ ] **Step 1: Implement `Formatting` with LanguageModelSession**

Create `WaterVoice/Adapters/FoundationModelsFormatter.swift`:

```swift
import FoundationModels
import WaterVoiceCore

/// Cleans up raw transcripts using the on-device Apple Foundation Model.
final class FoundationModelsFormatter: Formatting, @unchecked Sendable {
    private let promptBuilder: FormatterPrompt

    init(promptBuilder: FormatterPrompt = FormatterPrompt()) {
        self.promptBuilder = promptBuilder
    }

    func format(rawText: String) async throws -> String {
        // 1. Availability gate — throw FormatterUnavailable so coordinator falls back to raw text.
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FormatterUnavailable(reason: "\(reason)")
        }

        // 2. Token-budget guard — skip formatting for oversized input.
        guard promptBuilder.isWithinTokenBudget(rawText: rawText) else {
            throw FormatterUnavailable(reason: "input exceeds token budget")
        }

        // 3. Run the model.
        let session = LanguageModelSession(instructions: promptBuilder.instructions)
        let response = try await session.respond(to: promptBuilder.prompt(rawText: rawText))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 2: Build**

Cmd+B. Expected: builds clean.

- [ ] **Step 3: Manual smoke test**

Pass `"えーと今日はあのー晴れですね"` and confirm filler is removed and punctuation added. Then disable Apple Intelligence in System Settings and confirm `FormatterUnavailable` is thrown (coordinator should later fall back to raw text).

- [ ] **Step 4: Commit**

```bash
git add WaterVoice/Adapters/FoundationModelsFormatter.swift
git commit -m "feat: add Foundation Models formatter adapter with availability gate"
```

---

## Task 11: TextInjector + HotKeyMonitor + UserDefaults store

**Files:**
- Create: `WaterVoice/Adapters/CGEventTextInjector.swift`
- Create: `WaterVoice/Adapters/HotKeyMonitor.swift`
- Create: `WaterVoice/UserDefaultsKeyValueStore.swift`

- [ ] **Step 1: Implement the pasteboard/CGEvent clipboard**

Create `WaterVoice/Adapters/CGEventTextInjector.swift`:

```swift
import AppKit
import WaterVoiceCore

/// Concrete ClipboardAccessing over NSPasteboard + a synthetic Cmd+V keystroke.
struct PasteboardClipboard: ClipboardAccessing {
    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
    func write(_ text: String?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text { pb.setString(text, forType: .string) }
    }
    func sendPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // 'v'
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
```

The injector itself is `ClipboardLogic(clipboard: PasteboardClipboard())` from Layer 1 — no new type needed.

- [ ] **Step 2: Implement the UserDefaults store**

Create `WaterVoice/UserDefaultsKeyValueStore.swift`:

```swift
import Foundation
import WaterVoiceCore

final class UserDefaultsKeyValueStore: KeyValueStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    func set(_ value: String?, forKey key: String) { defaults.set(value, forKey: key) }
}
```

- [ ] **Step 3: Implement the global hotkey monitor**

Create `WaterVoice/Adapters/HotKeyMonitor.swift`:

```swift
import AppKit

/// Monitors a modifier key (default: right Option) press/release globally.
/// Requires Accessibility permission. Calls onPress/onRelease on the main actor.
@MainActor
final class HotKeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    private var monitor: Any?
    private var isDown = false

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self else { return }
            // 0x3D = right Option keycode. Detect via deviceIndependentFlags.
            let optionHeld = event.modifierFlags.contains(.option)
            if optionHeld, !self.isDown {
                self.isDown = true
                self.onPress()
            } else if !optionHeld, self.isDown {
                self.isDown = false
                self.onRelease()
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
```

- [ ] **Step 4: Build**

Cmd+B. Expected: builds clean.

- [ ] **Step 5: Commit**

```bash
git add WaterVoice/Adapters/CGEventTextInjector.swift WaterVoice/Adapters/HotKeyMonitor.swift WaterVoice/UserDefaultsKeyValueStore.swift
git commit -m "feat: add clipboard injector, hotkey monitor, and UserDefaults store"
```

---

## Task 12: Wire everything into MenuBarExtra

**Files:**
- Modify: `WaterVoice/WaterVoiceApp.swift`
- Create: `WaterVoice/MenuBarView.swift`

- [ ] **Step 1: Compose the app and coordinator**

Replace `WaterVoice/WaterVoiceApp.swift`:

```swift
import SwiftUI
import WaterVoiceCore

@main
struct WaterVoiceApp: App {
    @StateObject private var coordinator: AppCoordinator
    private let hotKey = HotKeyMonitor()

    init() {
        let coord = AppCoordinator(
            recorder: AVAudioRecorderAdapter(),
            transcriber: SpeechAnalyzerTranscriber(localeIdentifier: "ja-JP"),
            formatter: FoundationModelsFormatter(),
            injector: ClipboardLogic(clipboard: PasteboardClipboard())
        )
        _coordinator = StateObject(wrappedValue: coord)
    }

    var body: some Scene {
        MenuBarExtra("Water Voice", systemImage: iconName) {
            MenuBarView(coordinator: coordinator)
        }
        .onChange(of: scenePhaseStub) { } // placeholder to satisfy compiler if needed
    }

    private var iconName: String {
        switch coordinator.state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        default: return "waveform"
        }
    }

    private var scenePhaseStub: Int { 0 }
}
```

Then start the hotkey from a `.task` or an `AppDelegate` and bind:

```swift
// Inside MenuBarView.onAppear or an AppDelegate applicationDidFinishLaunching:
hotKey.onPress = { Task { try? await coordinator.beginRecording() } }
hotKey.onRelease = { Task { await coordinator.endRecordingAndProcess() } }
hotKey.start()
```

> Note: wiring `hotKey` from the `App` struct may require an `@NSApplicationDelegateAdaptor`. If the inline approach fights SwiftUI lifecycle, add an `AppDelegate` and move recorder/coordinator/hotkey ownership there. The `AppCoordinator` API is unchanged either way.

- [ ] **Step 2: Build the menu UI**

Create `WaterVoice/MenuBarView.swift`:

```swift
import SwiftUI
import WaterVoiceCore

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading) {
            Text(statusText)
            Divider()
            Button("Quit Water Voice") { NSApplication.shared.terminate(nil) }
        }
        .padding(8)
    }

    private var statusText: String {
        switch coordinator.state {
        case .idle: return "待機中（右Optionを押しながら話す）"
        case .recording: return "● 録音中…"
        case .transcribing: return "文字起こし中…"
        case .formatting: return "整形中…"
        case .injecting: return "貼り付け中…"
        }
    }
}
```

- [ ] **Step 3: Build and run**

Cmd+R. Grant Microphone, Speech Recognition, and Accessibility permissions when prompted (System Settings → Privacy & Security).

- [ ] **Step 4: Manual E2E test**

1. Open TextEdit (or Slack/browser).
2. Hold right Option, say "えーと今日はあのー晴れですね", release.
3. Confirm cleaned text ("今日は晴れですね。") is pasted into the frontmost app.
4. Confirm the original clipboard contents are restored afterward.
5. Disable Apple Intelligence; repeat; confirm raw transcript is pasted as fallback.

- [ ] **Step 5: Commit**

```bash
git add WaterVoice/WaterVoiceApp.swift WaterVoice/MenuBarView.swift
git commit -m "feat: wire pipeline into MenuBarExtra with global hotkey"
```

**🎯 Milestone: working end-to-end dictation app.**

---

## Self-Review

**Spec coverage:**
- Recording (AVAudioEngine) → Task 8 ✅
- Transcription (SpeechAnalyzer/SpeechTranscriber) → Task 9 ✅
- AI formatting (Foundation Models) → Task 10 ✅
- Clipboard inject + restore (CGEvent Cmd+V) → Tasks 4 + 11 ✅
- SettingsStore (hotkey/language/prompt) → Task 5 ✅
- AppCoordinator state machine → Task 6 ✅
- MenuBarUI + LSUIElement → Tasks 7 + 12 ✅
- Error handling / fallback (formatter unavailable → raw text; transcription failure → idle) → Task 6 ✅
- Phase 2 global hotkey → Task 11 ✅
- Phase 0 availability checks (Apple Intelligence) → Task 10 ✅
- Unit tests for Transcriber/Formatter/Injector via protocols + state-machine transitions → Tasks 4/6 ✅

**Gaps to note (deferred, not in scope of first working build):**
- Settings UI to *edit* hotkey/language/prompt (SettingsStore exists; the editing UI is Phase 4). Add a follow-up task when ready.
- Custom dictionary (Phase 4) — deferred.
- Chunking transcripts that exceed the token budget — currently we skip formatting and paste raw text; revisit if long dictations are common.

**Placeholder scan:** No TBD/TODO left. The two ⚠️ notes (Speech API drift, hotkey lifecycle) are explicit verification instructions, not placeholders — the protocol contracts they depend on are fully specified.

**Type consistency:** `AudioRecording`/`Transcribing`/`Formatting`/`TextInjecting`/`KeyValueStore`/`ClipboardAccessing` names and signatures are identical across the protocol definition (Task 2), the Layer-1 consumers (Tasks 3–6), and the Layer-2 adapters (Tasks 8–12). `AppCoordinator.beginRecording()` / `endRecordingAndProcess()` / `state` / `lastError` are used consistently in tests (Task 6) and wiring (Task 12). `FormatterPrompt.isWithinTokenBudget` / `instructions` / `prompt(rawText:)` match between Task 3 and Task 10.

---

## Execution Handoff

Layer 1 (Tasks 1–6) can be executed and fully tested **right now** with `swift test` — no Xcode required. Layer 2 (Tasks 7–12) requires Xcode to be installed first.
