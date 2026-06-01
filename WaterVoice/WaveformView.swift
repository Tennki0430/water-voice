import SwiftUI

/// A simple live bar-graph waveform driven by a normalized level (0...1).
/// Keeps a short rolling history of recent levels for a scrolling effect.
struct WaveformView: View {
    let level: Float
    let isActive: Bool

    @State private var history: [Float] = Array(repeating: 0, count: barCount)
    private static let barCount = 28

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width / CGFloat(Self.barCount) * 0.6
            let spacing = geo.size.width / CGFloat(Self.barCount) * 0.4
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<Self.barCount, id: \.self) { i in
                    Capsule()
                        .fill(barColor(for: history[i]))
                        .frame(
                            width: barWidth,
                            height: max(3, CGFloat(history[i]) * geo.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onChange(of: level) { _, newValue in
            guard isActive else { return }
            history.removeFirst()
            history.append(newValue)
        }
        .onChange(of: isActive) { _, active in
            if !active { history = Array(repeating: 0, count: Self.barCount) }
        }
    }

    private func barColor(for value: Float) -> Color {
        if value > 0.75 { return .red }
        if value > 0.45 { return .orange }
        return .green
    }
}
