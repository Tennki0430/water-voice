import AppKit
import Combine
import SwiftUI
import WaterVoiceCore

/// アプリのコーディネーター。録音・ホットキー・フローティングピル・統計・トーストを管理します。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: AppCoordinator
    let levelMonitor = AudioLevelMonitor()
    let hotKeyDebug  = HotKeyDebugInfo()
    let stats        = StatsTracker()

    private let hotKey    = HotKeyMonitor()
    private let recorder: AVAudioRecorderAdapter
    private let transcriber: any ConfigurableTranscriber
    private let pill  = FloatingPillController()
    private let toast = ToastController()
    private var cancellables: Set<AnyCancellable> = []

    // NSStatusItem — AppKit でメニューバーアイコンを表示
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var settingsWindowController: NSWindowController?

    override init() {
        let recorder   = AVAudioRecorderAdapter()
        // ④ 設定から言語を読み込む
        let settings   = SettingsStore(store: UserDefaultsKeyValueStore())
        // OS バージョンに応じて文字起こし・整形エンジンを選択（旧 OS 対応）
        let transcriber = EngineFactory.makeTranscriber(locale: settings.languageCode)

        self.recorder   = recorder
        self.transcriber = transcriber

        // トーン・カスタム辞書・アプリ別プロファイルを整形時に供給するプロバイダ
        let contextProvider = SettingsContextProvider(settings: settings)

        coordinator = AppCoordinator(
            recorder: recorder,
            transcriber: transcriber,
            formatter: EngineFactory.makeFormatter(),
            injector: ClipboardLogic(clipboard: PasteboardClipboard()),
            contextProvider: contextProvider
        )
        super.init()

        // マイクレベルをモニターに流す
        let monitor = levelMonitor
        recorder.onLevel = { level in
            Task { @MainActor in monitor.update(level) }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        hotKey.debugInfo = hotKeyDebug
        hotKey.requestAccessibilityIfNeeded()

        hotKey.onPress = { [weak self] in
            guard let self else { return }
            Log.pipeline.notice("onPress -> beginRecording")
            SoundPlayer.playBegin()
            Task {
                do { try await self.coordinator.beginRecording() }
                catch { Log.pipeline.error("beginRecording failed: \(error)") }
            }
        }
        hotKey.onRelease = { [weak self] in
            guard let self else { return }
            Log.pipeline.notice("onRelease -> endRecordingAndProcess")
            SoundPlayer.playEnd()
            Task {
                await self.coordinator.endRecordingAndProcess()
                self.levelMonitor.reset()

                // ① 統計を記録 ③ トーストを表示
                if let lastError = self.coordinator.lastError {
                    Log.pipeline.error("pipeline error: \(lastError)")
                } else {
                    // クリップボードの内容を読んで統計・トーストに使う
                    // （ClipboardLogicが復元する前にAppCoordinatorが通知してくれる仕組みがないため、
                    //   Coordinatorの仕上がりを state 変化で監視し、pasteboardの値を使う）
                }
            }
        }
        hotKey.start()

        // 状態変化を監視
        coordinator.$state
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .recording:
                    self.pill.show(
                        levelMonitor: self.levelMonitor,
                        onCancel: { [weak self] in
                            Task { await self?.coordinator.cancelRecording(); self?.levelMonitor.reset() }
                        },
                        onStop: { [weak self] in
                            Task { await self?.coordinator.endRecordingAndProcess(); self?.levelMonitor.reset() }
                        }
                    )
                case .idle:
                    self.pill.hide()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.stop()
    }

    /// 言語設定が変わったときに呼ぶ（設定ウィンドウから）。
    func updateLanguage(_ code: String) {
        transcriber.localeIdentifier = code
    }

    // MARK: - NSStatusItem (AppKit fallback)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "WaterVoice"
        item.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Water Voice")
        item.button?.image?.isTemplate = true
        item.isVisible = true

        let menu = NSMenu()
        menu.addItem(withTitle: "録音を開始", action: #selector(startRecording), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Water Voice を終了", action: #selector(quitApp), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
        statusMenu = menu

        // 状態変化でアイコンを更新
        coordinator.$state
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self, let button = self.statusItem?.button else { return }
                let name: String
                switch state {
                case .idle:        name = "mic"
                case .recording:   name = "mic.fill"
                default:           name = "waveform.circle"
                }
                button.image = NSImage(systemSymbolName: name, accessibilityDescription: "Water Voice")
                button.image?.isTemplate = true
                self.updateMenu(state: state)
            }
            .store(in: &cancellables)
    }

    private func updateMenu(state: DictationState) {
        guard let menu = statusMenu else { return }
        menu.removeAllItems()
        if state == .recording {
            menu.addItem(withTitle: "録音を停止", action: #selector(stopRecording), keyEquivalent: "")
            menu.addItem(withTitle: "録音をキャンセル", action: #selector(cancelRecording), keyEquivalent: "")
        } else {
            let startItem = menu.addItem(withTitle: "録音を開始", action: #selector(startRecording), keyEquivalent: "")
            startItem.isEnabled = state == .idle
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Water Voice を終了", action: #selector(quitApp), keyEquivalent: "q")
    }

    @objc private func startRecording() {
        Task { try? await coordinator.beginRecording() }
    }

    @objc private func stopRecording() {
        Task { await coordinator.endRecordingAndProcess(); levelMonitor.reset() }
    }

    @objc private func cancelRecording() {
        Task { await coordinator.cancelRecording(); levelMonitor.reset() }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "設定"
            win.contentView = NSHostingView(rootView: SettingsView())
            win.center()
            settingsWindowController = NSWindowController(window: win)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
