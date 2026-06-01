import AVFoundation
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
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        // Ensure the locale assets are installed (download on first use).
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioFileURL)

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            try await analyzer.cancelAndFinishNow()
        }

        var text = ""
        for try await result in transcriber.results {
            text += String(result.text.characters)
        }
        return text
    }
}
