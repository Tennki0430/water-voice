import AppKit
import SwiftUI

/// Shows/hides the floating recording pill as a borderless, non-activating panel
/// pinned near the bottom-center of the active screen.
@MainActor
final class FloatingPillController {
    private var panel: NSPanel?

    func show(levelMonitor: AudioLevelMonitor, onCancel: @escaping () -> Void, onStop: @escaping () -> Void) {
        if panel != nil { return }

        let hosting = NSHostingView(
            rootView: PillContainer(levelMonitor: levelMonitor, onCancel: onCancel, onStop: onStop)
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = hosting
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false

        // Position bottom-center of the screen with the mouse, fallback to main.
        let screen = NSScreen.main ?? NSScreen.screens.first
        if let frame = screen?.visibleFrame {
            let size = hosting.fittingSize
            let x = frame.midX - size.width / 2
            let y = frame.minY + 80
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// Bridges the ObservableObject level into the SwiftUI pill.
private struct PillContainer: View {
    @ObservedObject var levelMonitor: AudioLevelMonitor
    var onCancel: () -> Void
    var onStop: () -> Void

    var body: some View {
        FloatingPillView(level: levelMonitor.level, onCancel: onCancel, onStop: onStop)
            .padding(6)
            .fixedSize()
    }
}
