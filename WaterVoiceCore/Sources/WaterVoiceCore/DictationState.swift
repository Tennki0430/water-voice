import Foundation

/// The states of the dictation state machine.
public enum DictationState: Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case formatting
    case injecting
}
