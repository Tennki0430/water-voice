import Foundation

/// An AI instruction spoken at the end of an utterance, e.g. "…英語にして".
public enum VoiceCommand: Sendable, Equatable {
    case translate(language: String)
    case bulletList
    case summarize
    case polite

    /// Instruction line appended to the formatter prompt for this command.
    public var instructionLine: String {
        switch self {
        case .translate(let language):
            return "本文を\(language)に翻訳して出力する。"
        case .bulletList:
            return "本文を箇条書き（各行頭に「- 」）に整理して出力する。"
        case .summarize:
            return "本文の要点を簡潔に要約して出力する。"
        case .polite:
            return "本文を丁寧な敬語に書き換えて出力する。"
        }
    }
}

/// Detects a trailing spoken command and strips it from the body text.
///
/// Example: "明日の会議の件です 英語にして" →
///   body = "明日の会議の件です", command = .translate(language: "英語")
public struct VoiceCommandParser: Sendable {
    public init() {}

    /// Trailing trigger phrases mapped to commands. Longest phrases first so
    /// "英語に翻訳して" matches before "英語にして".
    private var triggers: [(phrase: String, command: VoiceCommand)] {
        [
            ("英語に翻訳して", .translate(language: "英語")),
            ("英語にして", .translate(language: "英語")),
            ("日本語に翻訳して", .translate(language: "日本語")),
            ("日本語にして", .translate(language: "日本語")),
            ("中国語にして", .translate(language: "中国語")),
            ("箇条書きにして", .bulletList),
            ("箇条書きで", .bulletList),
            ("要約して", .summarize),
            ("敬語にして", .polite),
            ("丁寧にして", .polite),
        ]
    }

    /// Separators that may sit between the body and the trailing command.
    private let separators = CharacterSet(charactersIn: " 　、。,.\n\t")

    public func parse(_ text: String) -> (body: String, command: VoiceCommand?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for trigger in triggers {
            if trimmed.hasSuffix(trigger.phrase) {
                let bodyEnd = trimmed.index(trimmed.endIndex, offsetBy: -trigger.phrase.count)
                var body = String(trimmed[..<bodyEnd])
                body = body.trimmingCharacters(in: separators)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Only treat as a command if real body remains.
                guard !body.isEmpty else { continue }
                return (body, trigger.command)
            }
        }
        return (trimmed, nil)
    }
}
