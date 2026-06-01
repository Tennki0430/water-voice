import SwiftUI

/// The Aqua-Voice-style floating pill shown during recording:
/// a cancel button, a live waveform, and a stop button on a dark rounded capsule.
struct FloatingPillView: View {
    let level: Float
    var onCancel: () -> Void
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)

            PillWaveform(level: level)
                .frame(width: 140, height: 26)

            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }
}

/// A symmetric, center-weighted bar waveform like the reference UI.
private struct PillWaveform: View {
    let level: Float

    private static let barCount = 19
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let barSpacing = size.width / CGFloat(Self.barCount)
                let barWidth = barSpacing * 0.45
                let midY = size.height / 2
                let lvl = CGFloat(max(0.05, min(1, level)))

                for i in 0..<Self.barCount {
                    // Center bars are tallest; edges taper — like the reference image.
                    let distFromCenter = abs(Double(i) - Double(Self.barCount - 1) / 2)
                    let centerWeight = 1.0 - (distFromCenter / Double(Self.barCount)) * 1.4
                    let wobble = 0.5 + 0.5 * sin(now * 6 + Double(i) * 0.7)
                    let h = max(2, size.height * lvl * CGFloat(max(0, centerWeight)) * CGFloat(0.4 + 0.6 * wobble))

                    let x = barSpacing * CGFloat(i) + barSpacing / 2
                    let rect = CGRect(x: x - barWidth / 2, y: midY - h / 2, width: barWidth, height: h)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(.white.opacity(0.9))
                    )
                }
            }
        }
    }
}
