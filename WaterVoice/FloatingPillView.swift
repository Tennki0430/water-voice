import SwiftUI

/// Light, informative floating recording panel:
/// a center-weighted waveform on top, and a bottom row with a mic label
/// plus Stop / Cancel hints — matching the reference design.
struct FloatingPillView: View {
    let level: Float
    var onCancel: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            PillWaveform(level: level)
                .frame(height: 44)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                // Left: mic + label
                Image(systemName: "mic")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("音声文字起こし")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                // Right: Stop and Cancel with keycap hints
                Button(action: onStop) {
                    HStack(spacing: 4) {
                        Text("Stop").foregroundStyle(.primary)
                        KeyCap(text: "⌥")
                        KeyCap(text: "Space")
                    }
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    HStack(spacing: 4) {
                        Text("Cancel").foregroundStyle(.secondary)
                        KeyCap(text: "esc")
                    }
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
    }
}

/// A small keyboard-cap style label like "⌥" / "Space" / "esc".
private struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.gray.opacity(0.25), lineWidth: 0.5)
            )
    }
}

/// A symmetric, center-weighted dotted waveform like the reference UI.
private struct PillWaveform: View {
    let level: Float

    private static let barCount = 60

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let barSpacing = size.width / CGFloat(Self.barCount)
                let barWidth = barSpacing * 0.35
                let midY = size.height / 2
                // Boost responsiveness: small input still shows a lively wave.
                let boosted = CGFloat(min(1, pow(max(0.04, level), 0.6) * 1.4))

                for i in 0..<Self.barCount {
                    // Center-weighted envelope so the middle is tallest.
                    let t = Double(i) / Double(Self.barCount - 1)
                    let envelope = sin(t * .pi) // 0 at edges, 1 in center
                    let wobble = 0.5 + 0.5 * sin(now * 7 + Double(i) * 0.5)
                    let h = max(2, size.height * boosted * CGFloat(envelope) * CGFloat(0.55 + 0.45 * wobble))

                    let x = barSpacing * CGFloat(i) + barSpacing / 2
                    let rect = CGRect(x: x - barWidth / 2, y: midY - h / 2, width: barWidth, height: h)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(.secondary.opacity(0.55))
                    )
                }
            }
        }
    }
}
