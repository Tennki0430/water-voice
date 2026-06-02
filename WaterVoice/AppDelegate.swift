import AppKit
import Combine
import WaterVoiceCore

/// Owns the coordinator, global hotkey, and the floating recording pill.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: AppCoordinator
    let levelMonitor = AudioLevelMonitor()
    let hotKeyDebug = HotKeyDebugInfo()
    private let hotKey = HotKeyMonitor()
    private let recorder: AVAudioRecorderAdapter
    private let pill = FloatingPillController()
    private var cancellables: Set<AnyCancellable> = []

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
        // The global hotkey needs Accessibility permission; prompt on first launch.
        hotKey.debugInfo = hotKeyDebug
        hotKey.requestAccessibilityIfNeeded()

        hotKey.onPress = { [weak self] in
            guard let self else { return }
            Log.pipeline.notice("onPress -> beginRecording (state=\(String(describing: self.coordinator.state)))")
            Task {
                do { try await self.coordinator.beginRecording() }
                catch { Log.pipeline.error("beginRecording failed: \(error)") }
            }
        }
        hotKey.onRelease = { [weak self] in
            guard let self else { return }
            Log.pipeline.notice("onRelease -> endRecordingAndProcess (state=\(String(describing: self.coordinator.state)))")
            Task {
                await self.coordinator.endRecordingAndProcess()
                Log.pipeline.notice("endRecordingAndProcess done (state=\(String(describing: self.coordinator.state)), lastError=\(String(describing: self.coordinator.lastError)))")
                self.levelMonitor.reset()
            }
        }
        hotKey.start()

        // Show/hide the floating pill as recording starts/stops.
        coordinator.$state
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                if state == .recording {
                    self.pill.show(
                        levelMonitor: self.levelMonitor,
                        onCancel: { [weak self] in
                            Task { await self?.coordinator.cancelRecording(); self?.levelMonitor.reset() }
                        },
                        onStop: { [weak self] in
                            Task { await self?.coordinator.endRecordingAndProcess(); self?.levelMonitor.reset() }
                        }
                    )
                } else {
                    self.pill.hide()
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.stop()
    }
}
