import CrayonKit
import SwiftUI

/// A recorded voice note: play button (56), a little waveform and the length.
/// Recording itself arrives later (M5).
public struct VoiceNote: View {
    private let duration: Duration
    private let isPlaying: Bool
    private let onPlay: () -> Void

    public init(duration: Duration, isPlaying: Bool, onPlay: @escaping () -> Void) {
        self.duration = duration
        self.isPlaying = isPlaying
        self.onPlay = onPlay
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(CrayonColor.card)
                    .frame(width: 56, height: 56)
                    .crayonBackground(.circle, fill: CrayonStyle.blueCrayon, seed: CrayonStyle.Seed.voice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            HStack(spacing: 4) {
                ForEach(Array([10, 22, 16, 30, 18, 26, 12, 20].enumerated()), id: \.offset) { _, h in
                    Capsule().fill(CrayonColor.ink).frame(width: 5, height: CGFloat(h))
                }
            }
            .accessibilityHidden(true)
            Text(duration.formatted(.time(pattern: .minuteSecond)))
                .crayonType(.caption)
                .foregroundStyle(CrayonColor.softText)
                .monospacedDigit()
        }
    }
}
