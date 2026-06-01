import AppKit
import WaterVoiceCore

/// Owns the coordinator and global hotkey, wiring press/release to the pipeline.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: AppCoordinator
    let levelMonitor = AudioLevelMonitor()
    private let hotKey = HotKeyMonitor()
    private let recorder: AVAudioRecorderAdapter

    override init() {
        let recorder = AVAudioRecorderAdapter()
        self.recorder = recorder
        coordinator = AppCoordinator(
            recorder: recorder,
            transcriber: SpeechAnalyzerTranscriber(localeIdentifier: "ja-JP"),
            formatter: FoundationModelsFormatter(),
            injector: ClipboardLogic(clipboard: PasteboardClipboard())
        )
        super.init()

        // Pump mic level into the monitor (hops to main for the @Published update).
        let monitor = levelMonitor
        recorder.onLevel = { level in
            Task { @MainActor in monitor.update(level) }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey.onPress = { [weak self] in
            guard let self else { return }
            Task { try? await self.coordinator.beginRecording() }
        }
        hotKey.onRelease = { [weak self] in
            guard let self else { return }
            Task {
                await self.coordinator.endRecordingAndProcess()
                self.levelMonitor.reset()
            }
        }
        hotKey.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.stop()
    }
}
