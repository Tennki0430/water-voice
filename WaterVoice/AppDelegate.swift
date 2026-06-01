import AppKit
import WaterVoiceCore

/// Owns the coordinator and global hotkey, wiring press/release to the pipeline.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: AppCoordinator
    private let hotKey = HotKeyMonitor()

    override init() {
        coordinator = AppCoordinator(
            recorder: AVAudioRecorderAdapter(),
            transcriber: SpeechAnalyzerTranscriber(localeIdentifier: "ja-JP"),
            formatter: FoundationModelsFormatter(),
            injector: ClipboardLogic(clipboard: PasteboardClipboard())
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey.onPress = { [weak self] in
            guard let self else { return }
            Task { try? await self.coordinator.beginRecording() }
        }
        hotKey.onRelease = { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.endRecordingAndProcess() }
        }
        hotKey.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.stop()
    }
}
