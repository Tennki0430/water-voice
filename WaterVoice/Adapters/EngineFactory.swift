import WaterVoiceCore

/// ロケールを後から変更できる文字起こしアダプタ。
protocol ConfigurableTranscriber: AnyObject, Transcribing {
    var localeIdentifier: String { get set }
}

/// OS バージョンに応じて最適なエンジンを組み立てるファクトリ。
///
/// - 文字起こし: macOS 26+ は SpeechAnalyzer、旧 OS は SFSpeechRecognizer。
/// - AI 整形: macOS 26+ は Foundation Models → Ollama → ルールベース、
///   旧 OS は Ollama（任意）→ ルールベース の順にフォールバック。
enum EngineFactory {
    static func makeTranscriber(locale: String) -> any ConfigurableTranscriber {
        if #available(macOS 26, *) {
            return SpeechAnalyzerTranscriber(localeIdentifier: locale)
        }
        return SFSpeechTranscriber(localeIdentifier: locale)
    }

    static func makeFormatter() -> any Formatting {
        if #available(macOS 26, *) {
            return FallbackFormatter(primaries: [FoundationModelsFormatter(), OllamaFormatter()])
        }
        return FallbackFormatter(primaries: [OllamaFormatter()])
    }
}
