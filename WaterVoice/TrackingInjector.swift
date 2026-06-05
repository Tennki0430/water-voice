import Foundation
import WaterVoiceCore

/// ClipboardLogic をラップして、貼り付け後に統計記録とトースト表示を行うアダプタ。
@MainActor
final class TrackingInjector: TextInjecting {
    private let inner: ClipboardLogic
    private let stats: StatsTracker
    private let toast: ToastController

    init(stats: StatsTracker, toast: ToastController) {
        self.inner = ClipboardLogic(clipboard: PasteboardClipboard())
        self.stats = stats
        self.toast = toast
    }

    func inject(text: String) async throws {
        try await inner.inject(text: text)
        // ① 統計を記録
        stats.record(text: text)
        // ③ トーストを表示
        toast.show(text: text)
    }
}
