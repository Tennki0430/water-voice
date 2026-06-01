import SwiftUI
import WaterVoiceCore

/// Temporary debug window to verify the pipeline works end-to-end with visible controls.
/// Remove once the menu-bar flow is confirmed.
struct DebugView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var levelMonitor: AudioLevelMonitor
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Water Voice — デバッグ")
                .font(.title2).bold()

            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.headline)
            }

            WaveformView(
                level: levelMonitor.level,
                isActive: coordinator.state == .recording
            )
            .frame(height: 56)
            .padding(.vertical, 4)

            Text("「録音開始」を押して話し、「停止して処理」を押すと、文字起こし→整形→最前面アプリへ貼り付けます。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("● 録音開始") {
                    Task {
                        isBusy = true
                        try? await coordinator.beginRecording()
                        isBusy = false
                    }
                }
                .disabled(coordinator.state != .idle)

                Button("■ 停止して処理") {
                    Task {
                        isBusy = true
                        await coordinator.endRecordingAndProcess()
                        isBusy = false
                    }
                }
                .disabled(coordinator.state != .recording)
            }

            if let err = coordinator.lastError {
                Text("最後のエラー: \(String(describing: err))")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(width: 420, height: 280)
    }

    private var statusText: String {
        switch coordinator.state {
        case .idle: return "待機中"
        case .recording: return "● 録音中…"
        case .transcribing: return "文字起こし中…"
        case .formatting: return "整形中…"
        case .injecting: return "貼り付け中…"
        }
    }

    private var stateColor: Color {
        switch coordinator.state {
        case .idle: return .gray
        case .recording: return .red
        default: return .orange
        }
    }
}
