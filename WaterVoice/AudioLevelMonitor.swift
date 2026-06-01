import SwiftUI

/// Publishes the live microphone input level (0...1) so the UI can render a waveform.
@MainActor
final class AudioLevelMonitor: ObservableObject {
    /// Normalized level, 0 (silent) ... 1 (loud).
    @Published var level: Float = 0

    func update(_ newLevel: Float) {
        // Light smoothing so the meter doesn't flicker harshly.
        level = level * 0.6 + newLevel * 0.4
    }

    func reset() {
        level = 0
    }
}
