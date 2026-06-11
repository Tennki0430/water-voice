import SwiftUI
import WaterVoiceCore

@main
struct WaterVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Water Voice", systemImage: "mic") {
            MenuBarView(coordinator: appDelegate.coordinator)
        }

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
