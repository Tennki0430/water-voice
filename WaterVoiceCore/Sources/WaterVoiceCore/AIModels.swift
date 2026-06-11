import Foundation

public struct GeminiModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String

    public static let all: [GeminiModel] = [
        GeminiModel(id: "gemini-2.5-flash",       displayName: "Gemini 2.5 Flash（推奨・高速）"),
        GeminiModel(id: "gemini-2.5-pro",          displayName: "Gemini 2.5 Pro（高精度）"),
        GeminiModel(id: "gemini-2.0-flash",        displayName: "Gemini 2.0 Flash（安定版）"),
    ]

    public static var defaultModel: GeminiModel { all[0] }
}

public struct ClaudeModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String

    public static let all: [ClaudeModel] = [
        ClaudeModel(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5（高速・低コスト）"),
        ClaudeModel(id: "claude-sonnet-4-6",         displayName: "Claude Sonnet 4.6（バランス）"),
        ClaudeModel(id: "claude-opus-4-8",           displayName: "Claude Opus 4.8（最高精度）"),
    ]

    public static var defaultModel: ClaudeModel { all[0] }
}
