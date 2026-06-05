import Foundation
import Speech
import WaterVoiceCore

/// 文字起こしのフォールバック実装（macOS 13〜）。
/// 旧 OS でも動く `SFSpeechRecognizer` を使い、可能な場合はオンデバイス認識を要求します。
final class SFSpeechTranscriber: ConfigurableTranscriber, @unchecked Sendable {
    var localeIdentifier: String

    init(localeIdentifier: String = "ja-JP") {
        self.localeIdentifier = localeIdentifier
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriberUnavailable(reason: "SFSpeechRecognizer 利用不可: \(localeIdentifier)")
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !didResume { didResume = true; continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                if !didResume {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

/// `SFSpeechTranscriber` が使えないときに投げるエラー。
struct TranscriberUnavailable: Error {
    let reason: String
}
