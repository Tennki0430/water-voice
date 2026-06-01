import SwiftUI
import WaterVoiceCore

@main
struct WaterVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // DEBUG: visible window + Dock icon to verify the pipeline.
        // Revert to MenuBarExtra-only once confirmed.
        Window("Water Voice", id: "debug") {
            DebugView(
                coordinator: appDelegate.coordinator,
                levelMonitor: appDelegate.levelMonitor
            )
        }

        MenuBarExtra {
            MenuBarView(coordinator: appDelegate.coordinator)
        } label: {
            MenuBarLabel(
                coordinator: appDelegate.coordinator,
                levelMonitor: appDelegate.levelMonitor
            )
        }
    }
}

/// Menu-bar label that reflects the current dictation state.
/// While recording it shows a volume-reactive waveform; otherwise a mic icon.
private struct MenuBarLabel: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var levelMonitor: AudioLevelMonitor

    var body: some View {
        switch coordinator.state {
        case .idle:
            Image(systemName: "mic")
        case .recording:
            // variableValue drives how many waveform bars light up by mic level.
            Image(systemName: "waveform", variableValue: Double(levelMonitor.level))
                .symbolRenderingMode(.hierarchical)
        case .transcribing, .formatting, .injecting:
            Image(systemName: "waveform.circle")
        }
    }
}
