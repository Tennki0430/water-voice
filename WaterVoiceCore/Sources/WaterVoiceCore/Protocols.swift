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
