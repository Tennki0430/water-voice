import AppKit
import ApplicationServices
import OSLog

/// Monitors a modifier key (default: right Option) press/release globally.
/// Requires Accessibility permission. Calls onPress/onRelease on the main actor.
@MainActor
final class HotKeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    /// Optional debug sink shown in the debug window.
    var debugInfo: HotKeyDebugInfo?
    private var monitor: Any?
    private var isDown = false

    /// True when this app is trusted for Accessibility (required for the global monitor).
    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompts the user to grant Accessibility access if not already trusted.
    @discardableResult
    func requestAccessibilityIfNeeded() -> Bool {
        // kAXTrustedCheckOptionPrompt isn't concurrency-safe to reference directly
        // under Swift 6; its documented string value is "AXTrustedCheckOptionPrompt".
        let key = "AXTrustedCheckOptionPrompt"
        let trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        Log.pipeline.notice("AXIsProcessTrusted (with prompt) = \(trusted)")
        return trusted
    }

    func start() {
        let trusted = isTrusted
        Log.pipeline.notice("HotKeyMonitor.start trusted=\(trusted)")
        debugInfo?.isTrusted = trusted

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self else { return }
            let optionHeld = event.modifierFlags.contains(.option)
            self.debugInfo?.recordEvent("flagsChanged option=\(optionHeld) isDown=\(self.isDown)")
            if optionHeld, !self.isDown {
                self.isDown = true
                self.onPress()
            } else if !optionHeld, self.isDown {
                self.isDown = false
                self.onRelease()
            }
        }
        debugInfo?.monitorInstalled = (monitor != nil)
        Log.pipeline.notice("monitor installed = \(self.monitor != nil)")
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
