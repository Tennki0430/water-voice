import AppKit

/// macOSの音声認識サウンドを再生するユーティリティ。
/// システムの speech_recognition_did_begin/end.aiff を使用するため、
/// ユーザーにとって馴染みのある音になります。
enum SoundPlayer {
    private static let beginSound: NSSound? = NSSound(
        contentsOfFile: "/System/Library/PrivateFrameworks/MagnifierSupport.framework/Versions/A/Resources/speech_recognition_did_begin.aiff",
        byReference: true
    )
    private static let endSound: NSSound? = NSSound(
        contentsOfFile: "/System/Library/PrivateFrameworks/MagnifierSupport.framework/Versions/A/Resources/speech_recognition_did_end.aiff",
        byReference: true
    )

    static func playBegin() {
        if let s = beginSound?.copy() as? NSSound {
            s.volume = 0.5
            s.play()
        }
    }

    static func playEnd() {
        if let s = endSound?.copy() as? NSSound {
            s.volume = 0.5
            s.play()
        }
    }
}
