import AppKit
import WaterVoiceCore

/// Concrete ClipboardAccessing over NSPasteboard + a synthetic Cmd+V keystroke.
struct PasteboardClipboard: ClipboardAccessing {
    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func write(_ text: String?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text { pb.setString(text, forType: .string) }
    }

    func sendPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // 'v'
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
