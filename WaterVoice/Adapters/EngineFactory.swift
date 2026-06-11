import WaterVoiceCore

/// ロケールを後から変更できる文字起こしアダプタ。
protocol ConfigurableTranscriber: AnyObject, Transcribing {
    var localeIdentifier: String { get set }
}

/// OS バージョンに応じて最適なエンジンを組み立てるファクトリ。
enum EngineFactory {
    static func makeTranscriber(locale: String) -> any ConfigurableTranscriber {
        if #available(macOS 26, *) {
            return SpeechAnalyzerTranscriber(localeIdentifier: locale)
        }
        return SFSpeechTranscriber(localeIdentifier: locale)
    }

    /// 設定を読んで適切なフォーマッターを返す。
    /// API エンジンが選ばれていてもキー未入力ならオンデバイスにフォールバック。
    static func makeFormatter(settings: SettingsStore) -> any Formatting {
        let onDevice = makeOnDeviceFormatter()

        switch settings.formatterEngine {
        case .auto:
            return onDevice

        case .gemini:
            guard let key = settings.geminiApiKey, !key.isEmpty else { return onDevice }
            return FallbackFormatter(
                primaries: [GeminiFormatter(apiKey: key, model: settings.geminiModel)],
                fallback: onDevice
            )

        case .claude:
            guard let key = settings.claudeApiKey, !key.isEmpty else { return onDevice }
            return FallbackFormatter(
                primaries: [ClaudeFormatter(apiKey: key, model: settings.claudeModel)],
                fallback: onDevice
            )
        }
    }

    private static func makeOnDeviceFormatter() -> any Formatting {
        if #available(macOS 26, *) {
            return FallbackFormatter(primaries: [FoundationModelsFormatter(), OllamaFormatter()])
        }
        return FallbackFormatter(primaries: [OllamaFormatter()])
    }
}
