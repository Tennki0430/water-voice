import AVFoundation
import WaterVoiceCore

/// Records mic input to a temporary file using AVAudioEngine.
final class AVAudioRecorderAdapter: AudioRecording, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("watervoice-\(UUID().uuidString).caf")

    func startRecording() async throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("watervoice-\(UUID().uuidString).caf")
        file = try AVAudioFile(forWriting: outputURL, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
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
}
