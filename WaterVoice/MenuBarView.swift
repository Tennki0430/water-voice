import SwiftUI
import WaterVoiceCore

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Water Voice")
                .font(.headline)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            Button("Water Voice を終了") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 240)
    }

    private var statusText: String {
        switch coordinator.state {
        case .idle: return "待機中（右Optionを押しながら話す）"
        case .recording: return "● 録音中…"
        case .transcribing: return "文字起こし中…"
        case .formatting: return "整形中…"
        case .injecting: return "貼り付け中…"
        }
    }
}
