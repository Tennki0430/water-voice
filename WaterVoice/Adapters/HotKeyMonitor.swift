import AppKit

/// Monitors a modifier key (default: right Option) press/release globally.
/// Requires Accessibility permission. Calls onPress/onRelease on the main actor.
@MainActor
final class HotKeyMonitor {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    private var monitor: Any?
    private var isDown = false

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self else { return }
            // Detect the Option modifier being held/released.
            let optionHeld = event.modifierFlags.contains(.option)
            if optionHeld, !self.isDown {
                self.isDown = true
                self.onPress()
            } else if !optionHeld, self.isDown {
                self.isDown = false
                self.onRelease()
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
