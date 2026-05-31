import Foundation

/// Abstraction over the system pasteboard + paste keystroke, so sequencing is testable.
public protocol ClipboardAccessing: Sendable {
    func read() -> String?
    func write(_ text: String?)
    /// Sends the Cmd+V keystroke to the frontmost app.
    func sendPaste()
}

/// Pure sequencing: snapshot original clipboard, write new text, paste, restore original.
/// Conforms to `TextInjecting` so it drops straight into the coordinator.
public struct ClipboardLogic: TextInjecting {
    private let clipboard: ClipboardAccessing
    /// Delay (nanoseconds) to let the paste land before restoring the original.
    private let restoreDelayNanos: UInt64

    public init(clipboard: ClipboardAccessing, restoreDelayNanos: UInt64 = 100_000_000) {
        self.clipboard = clipboard
        self.restoreDelayNanos = restoreDelayNanos
    }

    public func inject(text: String) async throws {
        let original = clipboard.read()
        clipboard.write(text)
        clipboard.sendPaste()
        if restoreDelayNanos > 0 {
            try? await Task.sleep(nanoseconds: restoreDelayNanos)
        }
        clipboard.write(original)
    }
}
