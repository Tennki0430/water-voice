import Foundation
import WaterVoiceCore

/// Formats transcribed text using the Gemini API (gemini-2.0-flash).
final class GeminiFormatter: Formatting, @unchecked Sendable {
    private let apiKey: String
    private let model: String
    private let promptBuilder: FormatterPrompt

    init(apiKey: String, model: String = "gemini-2.0-flash", promptBuilder: FormatterPrompt = FormatterPrompt()) {
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

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": promptBuilder.instructions(context: context)]]],
            "contents": [["parts": [["text": promptBuilder.prompt(rawText: rawText)]]]],
            "generationConfig": ["temperature": 0.1, "maxOutputTokens": 2048]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FormatterUnavailable(reason: "Gemini 接続エラー: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw FormatterUnavailable(reason: "Gemini 応答不正")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "不明"
            throw FormatterUnavailable(reason: "Gemini HTTP \(http.statusCode): \(msg.prefix(120))")
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw FormatterUnavailable(reason: "Gemini 応答パースエラー")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
