import AVFoundation
import Speech
import WaterVoiceCore

/// 音声ファイルをオンデバイスの SpeechAnalyzer/SpeechTranscriber で文字起こしします（macOS 26+）。
/// ④ 言語は SettingsStore の languageCode を起動時に読み取ります。
///
/// 固有名詞・専門用語の正規化（カスタム辞書）は、文字起こし後の整形段階
/// （FoundationModelsFormatter + CustomDictionary）で行います。
@available(macOS 26, *)
final class SpeechAnalyzerTranscriber: ConfigurableTranscriber, @unchecked Sendable {
    var localeIdentifier: String

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

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // ロケールアセットのインストール（初回のみダウンロード）
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

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
