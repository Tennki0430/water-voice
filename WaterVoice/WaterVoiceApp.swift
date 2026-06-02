import SwiftUI
import WaterVoiceCore

@main
struct WaterVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: appDelegate.coordinator)
        } label: {
            MenuBarLabel(coordinator: appDelegate.coordinator)
        }

        // Opened on demand from the menu.
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

/// Menu-bar label: mic when idle, filled mic while recording, spinner-ish while processing.
private struct MenuBarLabel: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.state {
        case .idle:
            Image(systemName: "mic")
        case .recording:
            Image(systemName: "mic.fill")
        case .transcribing, .formatting, .injecting:
            Image(systemName: "waveform.circle")
        }
    }
}
