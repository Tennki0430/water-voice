import Foundation

/// Dependency-free, deterministic cleanup used as the universal baseline
/// (works on every macOS version, no model required).
///
/// It removes common Japanese fillers, tidies whitespace, applies the custom
/// dictionary as literal replacements, and ensures sentence-ending punctuation.
/// Tone and AI commands are out of scope here — those need a real LLM, so on
/// older systems they are only honored when Ollama is configured.
public struct RuleBasedFormatter: Formatting, Sendable {
    /// Filler expressions removed from the transcript.
    public static let defaultFillers: [String] = [
        "えーと", "えーっと", "えっと", "ええと",
        "あのー", "あのう", "あの、", "そのー",
        "なんか", "まあ", "ええ、", "うーん",
    ]

    private let fillers: [String]

    public init(fillers: [String] = RuleBasedFormatter.defaultFillers) {
        self.fillers = fillers
    }

    public func format(rawText: String) async throws -> String {
        clean(rawText, dictionary: CustomDictionary(entries: []))
    }

    public func format(rawText: String, context: FormatterContext) async throws -> String {
        clean(rawText, dictionary: context.dictionary)
    }

    /// Pure, synchronous cleanup — exposed for unit testing.
    public func clean(_ input: String, dictionary: CustomDictionary) -> String {
        var text = input

        // 1. Custom dictionary: literal spoken → written replacements.
        for entry in dictionary.entries {
            text = text.replacingOccurrences(of: entry.spoken, with: entry.written)
        }

        // 2. Remove fillers.
        for filler in fillers {
            text = text.replacingOccurrences(of: filler, with: "")
        }

        // 3. Collapse runs of spaces and trim.
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Ensure a sentence-ending mark for non-empty Japanese text.
        if let last = text.last, !"。．.！!？?、,".contains(last) {
            text.append("。")
        }
        return text
    }
}
