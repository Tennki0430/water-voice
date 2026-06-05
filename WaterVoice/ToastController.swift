import AppKit
import SwiftUI

/// 整形後テキストを画面上部に一瞬表示するトーストを管理します。
@MainActor
final class ToastController {
    private var panel: NSPanel?

    func show(text: String) {
        hide()

        let hosting = NSHostingView(rootView: ToastView(text: text))
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 72)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = hosting
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 画面上部中央に配置
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            let x = f.midX - hosting.frame.width / 2
            let y = f.maxY - hosting.frame.height - 16
            panel.setFrame(NSRect(x: x, y: y, width: hosting.frame.width, height: hosting.frame.height), display: true)
        }

        panel.orderFrontRegardless()
        self.panel = panel

        // 2.5秒後に自動で消える
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.hide()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ToastView: View {
    let text: String
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
            Text(text.count > 60 ? String(text.prefix(60)) + "…" : text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) { opacity = 1 }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
            }
        }
    }
}
