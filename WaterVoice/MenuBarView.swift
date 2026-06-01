import SwiftUI
import WaterVoiceCore

/// The menu shown when clicking the menu-bar icon. Modeled on Aqua Voice's menu.
struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Status line
        Text(statusText)

        Divider()

        // Primary action: start / stop dictation
        if coordinator.state == .recording {
            Button("録音を停止") {
                Task { await coordinator.endRecordingAndProcess() }
            }
            Button("録音をキャンセル") {
                Task { await coordinator.cancelRecording() }
            }
        } else {
            Button("録音を開始") {
                Task { try? await coordinator.beginRecording() }
            }
            .disabled(coordinator.state != .idle)
        }

        Divider()

        // Aqua-Voice-style configuration entries
        Button("設定…") { openWindow(id: "settings") }
            .keyboardShortcut(",", modifiers: .command)
        Button("辞書を編集…") { openWindow(id: "settings") }
        Button("カスタム指示…") { openWindow(id: "settings") }
        Button("統計情報…") { openWindow(id: "stats") }

        Divider()

        Button("デバッグウィンドウを開く") { openWindow(id: "debug") }

        Divider()

        Button("Water Voice を終了") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
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
