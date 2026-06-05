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

    /// Context-aware instructions: base rules plus tone, custom dictionary,
    /// and any spoken AI command. Used by the on-device formatter.
    public func instructions(context: FormatterContext) -> String {
        var lines = [instructions]
        if let tone = context.tone.instructionLine {
            lines.append("追加ルール: \(tone)")
        }
        if let dict = context.dictionary.instructionLine {
            lines.append("追加ルール: \(dict)")
        }
        if let command = context.command?.instructionLine {
            // A command can override the base "do not translate/summarize" rule,
            // so state it explicitly and last for priority.
            lines.append("最優先の指示: \(command)")
        }
        return lines.joined(separator: "\n\n")
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
