import AppKit
import WaterVoiceCore

/// Builds the live `FormatterContext` at the moment a transcript is ready:
/// resolves the tone from the frontmost app's profile (falling back to the
/// default tone) and attaches the user's custom dictionary.
///
/// `command` is left nil here — the `AppCoordinator` parses spoken commands
/// from the transcript and fills it in.
final class SettingsContextProvider: FormatterContextProviding, @unchecked Sendable {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func currentContext() async -> FormatterContext {
        let bundleID = await frontmostAppBundleID()
        let tone = settings.profileResolver.tone(forBundleID: bundleID)
        let dictionary = CustomDictionary(entries: settings.dictionaryEntries)
        return FormatterContext(tone: tone, dictionary: dictionary, command: nil)
    }

    /// Reads the frontmost (active) application's bundle identifier on the main actor.
    @MainActor
    private func frontmostAppBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
