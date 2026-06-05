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
    private let contextProvider: FormatterContextProviding?
    private let commandParser: VoiceCommandParser

    public init(
        recorder: AudioRecording,
        transcriber: Transcribing,
        formatter: Formatting,
        injector: TextInjecting,
        contextProvider: FormatterContextProviding? = nil,
        commandParser: VoiceCommandParser = VoiceCommandParser()
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.formatter = formatter
        self.injector = injector
        self.contextProvider = contextProvider
        self.commandParser = commandParser
    }

    /// Hotkey pressed: begin recording. Throws if recording can't start.
    public func beginRecording() async throws {
        guard state == .idle else { return }
        lastError = nil
        try await recorder.startRecording()
        state = .recording
    }

    /// Cancel an in-progress recording without transcribing or injecting.
    /// Discards the captured audio and returns to idle.
    public func cancelRecording() async {
        guard state == .recording else { return }
        _ = try? await recorder.stopRecording()
        state = .idle
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
            // Extract any spoken AI command (e.g. "…英語にして") and strip it
            // from the body before formatting.
            let parsed = commandParser.parse(trimmed)
            var context = await contextProvider?.currentContext() ?? .plain
            context.command = parsed.command
            let finalText = await formatOrFallback(rawText: parsed.body, context: context)

            state = .injecting
            try await injector.inject(text: finalText)

            state = .idle
        } catch {
            lastError = error
            state = .idle
        }
    }

    /// Formats the text, falling back to the raw text when the model is unavailable.
    private func formatOrFallback(rawText: String, context: FormatterContext) async -> String {
        do {
            return try await formatter.format(rawText: rawText, context: context)
        } catch {
            // Any formatter error (unavailable or otherwise) falls back to raw text;
            // we still surface it for the menu-bar UI to optionally show.
            lastError = error
            return rawText
        }
    }
}
