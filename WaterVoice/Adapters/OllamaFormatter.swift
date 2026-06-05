import Foundation
import WaterVoiceCore

/// AI 整形のフォールバック実装（macOS 13〜、任意）。
/// ローカルで動く Ollama（http://localhost:11434）に整形を依頼します。
/// Ollama が未起動・未インストールなら `FormatterUnavailable` を投げ、
/// 上位の `FallbackFormatter` がルールベース軽整形へ切り替えます。
final class OllamaFormatter: Formatting, @unchecked Sendable {
    private let endpoint: URL
    private let model: String
    private let promptBuilder: FormatterPrompt

    init(
        host: String = "http://localhost:11434",
        model: String = "qwen2.5:3b",
        promptBuilder: FormatterPrompt = FormatterPrompt()
    ) {
        self.endpoint = URL(string: "\(host)/api/generate")!
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

        let instructions = promptBuilder.instructions(context: context)
        let prompt = instructions + "\n\n" + promptBuilder.prompt(rawText: rawText)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FormatterUnavailable(reason: "Ollama 未起動: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            throw FormatterUnavailable(reason: "Ollama 応答エラー")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
