import Foundation

/// Output tone/style for formatting. Selectable in the menu and per-app profiles.
public enum DictationTone: String, Sendable, CaseIterable, Codable {
    case asIs
    case formal
    case casual
    case email
    case chat

    /// Instruction line appended to the formatter system prompt.
    /// `nil` means "do not impose a tone" (minimal cleanup only).
    public var instructionLine: String? {
        switch self {
        case .asIs:
            return nil
        case .formal:
            return "文体は丁寧でフォーマルな敬体（です・ます調）に統一する。"
        case .casual:
            return "文体は自然でカジュアルな口語に整える。"
        case .email:
            return "ビジネスメールにふさわしい敬語と段落構成に整える。"
        case .chat:
            return "チャットに適した、短く砕けた口語に整える。"
        }
    }

    /// Human-readable name for the settings UI / menu.
    public var displayName: String {
        switch self {
        case .asIs: return "そのまま"
        case .formal: return "フォーマル"
        case .casual: return "カジュアル"
        case .email: return "メール"
        case .chat: return "チャット"
        }
    }
}
