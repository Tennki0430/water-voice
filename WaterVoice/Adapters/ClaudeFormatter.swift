import Foundation
import WaterVoiceCore

/// Formats transcribed text using the Anthropic Claude API.
final class ClaudeFormatter: Formatting, @unchecked Sendable {
    private let apiKey: String
    private let model: String
    private let promptBuilder: FormatterPrompt

    init(
        apiKey: String,
        model: String = "claude-haiku-4-5-20251001",
        promptBuilder: FormatterPrompt = FormatterPrompt()
    ) {
        self.apiKey = apiKey
        self.model = model
        self.promptBuilder = promptBuilder
    }

    func format(rawText: String) async throws -> String {
        try await format(rawText: rawText, context: .plain)
    }

    func format(rawText: String, context: FormatterContext) async throws -> String {
        guard promptBuilder.isWithinTokenBudget(rawText: rawText) else {
            throw FormatterUnavailable(reason: "input exceeds token budget")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": promptBuilder.instructions(context: context),
            "messages": [["role": "user", "content": promptBuilder.prompt(rawText: rawText)]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FormatterUnavailable(reason: "Claude 接続エラー: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw FormatterUnavailable(reason: "Claude 応答不正")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "不明"
            throw FormatterUnavailable(reason: "Claude HTTP \(http.statusCode): \(msg.prefix(120))")
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contents = json["content"] as? [[String: Any]],
            let first = contents.first,
            let text = first["text"] as? String
        else {
            throw FormatterUnavailable(reason: "Claude 応答パースエラー")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
