import Foundation

/// Tries an ordered list of formatters and uses the first that succeeds.
/// If every primary throws (e.g. Foundation Models unavailable on old macOS,
/// or Ollama not running), it falls back to a guaranteed formatter that never
/// throws (typically `RuleBasedFormatter`).
///
/// This lets the app prefer the best available engine per OS while always
/// producing output.
public struct FallbackFormatter: Formatting, Sendable {
    private let primaries: [any Formatting]
    private let fallback: any Formatting

    public init(primaries: [any Formatting], fallback: any Formatting = RuleBasedFormatter()) {
        self.primaries = primaries
        self.fallback = fallback
    }

    public func format(rawText: String) async throws -> String {
        try await format(rawText: rawText, context: .plain)
    }

    public func format(rawText: String, context: FormatterContext) async throws -> String {
        for primary in primaries {
            if let result = try? await primary.format(rawText: rawText, context: context) {
                return result
            }
        }
        return try await fallback.format(rawText: rawText, context: context)
    }
}
