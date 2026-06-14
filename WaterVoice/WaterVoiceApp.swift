import SwiftUI
import WaterVoiceCore

@main
struct WaterVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("設定", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)

        Window("統計情報", id: "stats") {
            StatsView()
        }
        .windowResizability(.contentSize)

        Window("Water Voice — デバッグ", id: "debug") {
            DebugView(
                coordinator: appDelegate.coordinator,
                levelMonitor: appDelegate.levelMonitor,
                hotKeyDebug: appDelegate.hotKeyDebug
            )
        }
        .windowResizability(.contentSize)
    }
}
