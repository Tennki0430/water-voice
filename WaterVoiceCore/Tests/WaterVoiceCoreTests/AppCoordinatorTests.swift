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

    @MainActor
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

    @MainActor
    func test_startsIdle() {
        let c = makeCoordinator()
        XCTAssertEqual(c.state, .idle)
    }

    @MainActor
    func test_happyPath_injectsFormattedText_andReturnsToIdle() async throws {
        let injector = FakeInjector()
        let c = makeCoordinator(injector: injector)

        try await c.beginRecording()
        await c.endRecordingAndProcess()

        XCTAssertEqual(injector.injected, ["formatted text"])
        XCTAssertEqual(c.state, .idle)
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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
