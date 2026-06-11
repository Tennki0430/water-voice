import Foundation

/// Which AI formatter to use for post-processing transcribed text.
public enum FormatterEngine: String, CaseIterable, Sendable {
    case auto   = "auto"
    case gemini = "gemini"
    case claude = "claude"

    public var displayName: String {
        switch self {
        case .auto:   return "自動（オンデバイス）"
        case .gemini: return "Gemini API"
        case .claude: return "Claude API"
        }
    }
}
