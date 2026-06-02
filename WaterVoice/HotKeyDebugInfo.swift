import Foundation

/// Observable debug state surfaced in the debug window so we can diagnose the
/// global hotkey without relying on os_log (which can be hard to capture).
@MainActor
final class HotKeyDebugInfo: ObservableObject {
    @Published var isTrusted = false
    @Published var monitorInstalled = false
    @Published var flagsChangedCount = 0
    @Published var lastEvent = "（まだイベントなし）"

    func recordEvent(_ text: String) {
        flagsChangedCount += 1
        lastEvent = text
    }
}
