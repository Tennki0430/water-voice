import AVFoundation
import WaterVoiceCore

/// Records mic input to a temporary file using AVAudioEngine.
/// Also reports a normalized input level (0...1) via `onLevel` for UI metering.
final class AVAudioRecorderAdapter: AudioRecording, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("watervoice-\(UUID().uuidString).caf")

    /// Called on an audio thread with a normalized level (0...1) while recording.
    var onLevel: (@Sendable (Float) -> Void)?

    func startRecording() async throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("watervoice-\(UUID().uuidString).caf")
        file = try AVAudioFile(forWriting: outputURL, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.file?.write(from: buffer)
            self.onLevel?(Self.normalizedLevel(from: buffer))
        }
        engine.prepare()
        try engine.start()
    }

    func stopRecording() async throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        return outputURL
    }

    /// Computes a 0...1 level from a buffer's RMS, mapped through dBFS for a natural feel.
    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sumOfSquares: Float = 0
        for i in 0..<count {
            let sample = channel[i]
            sumOfSquares += sample * sample
        }
        let rms = (sumOfSquares / Float(count)).squareRoot()

        // Map RMS to dBFS, then to 0...1 over a -50...0 dB window.
        let db = 20 * log10(max(rms, 0.000_001))
        let clamped = max(-50, min(0, db))
        return (clamped + 50) / 50
    }
}
