import Foundation

/// A custom-vocabulary entry: when the model is unsure, prefer `written`
/// for things that sound like `spoken` (names, jargon, product/company names).
public struct DictionaryEntry: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    /// How the term tends to be (mis)heard, e.g. a reading like "さいとう".
    public var spoken: String
    /// The correct written form, e.g. "齋藤".
    public var written: String

    public init(id: UUID = UUID(), spoken: String, written: String) {
        self.id = id
        self.spoken = spoken
        self.written = written
    }

    /// True when both fields contain non-whitespace content.
    public var isUsable: Bool {
        !spoken.trimmingCharacters(in: .whitespaces).isEmpty
            && !written.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Builds the prompt fragment that teaches the model the user's preferred spellings.
public struct CustomDictionary: Sendable, Equatable {
    public let entries: [DictionaryEntry]

    public init(entries: [DictionaryEntry]) {
        self.entries = entries.filter(\.isUsable)
    }

    /// A single instruction line listing corrections, or `nil` when empty.
    public var instructionLine: String? {
        guard !entries.isEmpty else { return nil }
        let pairs = entries
            .map { "「\($0.spoken)」は「\($0.written)」" }
            .joined(separator: "、")
        return "次の固有名詞・専門用語の表記を優先する: \(pairs)。"
    }
}
