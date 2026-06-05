import Foundation

/// Everything that shapes a single formatting request beyond the raw text:
/// the chosen tone, the user's custom dictionary, and any spoken AI command.
public struct FormatterContext: Sendable, Equatable {
    public var tone: DictationTone
    public var dictionary: CustomDictionary
    public var command: VoiceCommand?

    public init(
        tone: DictationTone = .asIs,
        dictionary: CustomDictionary = CustomDictionary(entries: []),
        command: VoiceCommand? = nil
    ) {
        self.tone = tone
        self.dictionary = dictionary
        self.command = command
    }

    /// A context with no tone, no dictionary, and no command — plain cleanup.
    public static let plain = FormatterContext()
}

/// Maps a frontmost-app bundle identifier to a preferred tone.
/// Unknown apps fall back to `defaultTone`.
public struct AppProfileResolver: Sendable, Equatable {
    public var defaultTone: DictationTone
    public var profiles: [String: DictationTone]

    public init(defaultTone: DictationTone = .asIs, profiles: [String: DictationTone] = [:]) {
        self.defaultTone = defaultTone
        self.profiles = profiles
    }

    public func tone(forBundleID bundleID: String?) -> DictationTone {
        guard let bundleID, let tone = profiles[bundleID] else { return defaultTone }
        return tone
    }
}
