import SwiftUI
import WaterVoiceCore

@main
struct WaterVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Water Voice", systemImage: iconName) {
            MenuBarView(coordinator: appDelegate.coordinator)
        }
    }

    private var iconName: String {
        switch appDelegate.coordinator.state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        default: return "waveform"
        }
    }
}
