import AVFoundation
import SwiftUI
import WaterVoiceCore

/// Temporary debug window to verify the pipeline works end-to-end with visible controls.
struct DebugView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var levelMonitor: AudioLevelMonitor
    @ObservedObject var hotKeyDebug: HotKeyDebugInfo
    @State private var isBusy = false
    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Water Voice — デバッグ")
                .font(.title2).bold()

            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.headline)
            }

            GroupBox("権限の状態") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(
                            hotKeyDebug.isTrusted ? "アクセシビリティ: 許可済み" : "アクセシビリティ: 未許可 ← 貼り付けに必要",
                            systemImage: hotKeyDebug.isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(hotKeyDebug.isTrusted ? .green : .red)
                        Spacer()
                        if !hotKeyDebug.isTrusted {
                            Button("設定を開く") { openAccessibilitySettings() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    HStack {
                        Label(micLabel, systemImage: micStatus == .authorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(micStatus == .authorized ? .green : .red)
                        Spacer()
                        if micStatus != .authorized {
                            Button("マイクを許可") { requestMic() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.callout)
            }

            WaveformView(
                level: levelMonitor.level,
                isActive: coordinator.state == .recording
            )
            .frame(height: 44)

            HStack(spacing: 12) {
                Button("● 録音開始") {
                    Task {
                        isBusy = true
                        do { try await coordinator.beginRecording() }
                        catch { }
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

            // Result display — verifies transcription works independent of paste
            GroupBox("転写結果（最後）") {
                HStack(alignment: .top) {
                    Text(coordinator.lastResult ?? "まだ結果がありません")
                        .font(.callout)
                        .foregroundStyle(coordinator.lastResult == nil ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    if let result = coordinator.lastResult {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("クリップボードにコピー")
                    }
                }
            }

            if let err = coordinator.lastError {
                Text("エラー: \(String(describing: err))")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Text("💡 実際の使い方: テキストを入力したいアプリを開いたまま、右Optionキーを押しながら話して離す。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 460, height: 420)
    }

    private var micLabel: String {
        switch micStatus {
        case .authorized:    return "マイク: 許可済み"
        case .notDetermined: return "マイク: 未確認 ← 録音に必要"
        case .denied:        return "マイク: 拒否済み ← 設定で許可を"
        case .restricted:    return "マイク: 制限中"
        @unknown default:    return "マイク: 不明"
        }
    }

    private var statusText: String {
        switch coordinator.state {
        case .idle:         return "待機中"
        case .recording:    return "● 録音中…"
        case .transcribing: return "文字起こし中…"
        case .formatting:   return "整形中…"
        case .injecting:    return "貼り付け中…"
        }
    }

    private var stateColor: Color {
        switch coordinator.state {
        case .idle:      return .gray
        case .recording: return .red
        default:         return .orange
        }
    }

    private func requestMic() {
        Task {
            await AVCaptureDevice.requestAccess(for: .audio)
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
