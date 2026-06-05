import FoundationModels
import WaterVoiceCore

/// Cleans up raw transcripts using the on-device Apple Foundation Model.
final class FoundationModelsFormatter: Formatting, @unchecked Sendable {
    private let promptBuilder: FormatterPrompt

    init(promptBuilder: FormatterPrompt = FormatterPrompt()) {
        self.promptBuilder = promptBuilder
    }

    func format(rawText: String) async throws -> String {
        try await format(rawText: rawText, context: .plain)
    }

    func format(rawText: String, context: FormatterContext) async throws -> String {
        // 1. Availability gate — throw FormatterUnavailable so coordinator falls back to raw text.
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FormatterUnavailable(reason: "\(reason)")
        @unknown default:
            throw FormatterUnavailable(reason: "unknown availability")
        }

        // 2. Token-budget guard — skip formatting for oversized input.
        guard promptBuilder.isWithinTokenBudget(rawText: rawText) else {
            throw FormatterUnavailable(reason: "input exceeds token budget")
        }

        // 3. Run the model with context-aware instructions (tone, dictionary, command).
        let session = LanguageModelSession(instructions: promptBuilder.instructions(context: context))
        let response = try await session.respond(to: promptBuilder.prompt(rawText: rawText))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
