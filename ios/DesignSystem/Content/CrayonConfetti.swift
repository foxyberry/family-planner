import CrayonKit
import SwiftUI

/// Crayon confetti for the done moment (board 0g2): 24 small crayon pieces in the kit colours burst
/// from the centre over about 360 × 240 and fall away in 1.5 s. Reduce Motion: none. The caller
/// clips it to its region.
public struct CrayonConfetti: View {
    private let trigger: Int
    private let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A new `trigger` value plays it once; `scale` is the screen's s.
    public init(trigger: Int, scale: CGFloat = 1) {
        self.trigger = trigger
        self.scale = scale
    }

    private static let colors: [Color] = [CrayonPalette.goYellow, CrayonPalette.kidApricot, CrayonPalette.nowSky,
                                          CrayonPalette.pickBlue, CrayonPalette.leaf, CrayonPalette.coral].map(\.color)

    /// A fixed wobble per piece and channel, -1…1 (same every time).
    private static func jitter(_ index: Int, _ channel: Int) -> Double {
        let x = sin(Double(index * 12_9898 + channel * 78_233) * 0.001) * 43_758.5453
        return (x - x.rounded(.down)) * 2 - 1
    }

    public var body: some View {
        if !reduceMotion, trigger > 0 {
            ZStack {
                ForEach(0..<24, id: \.self) { index in
                    piece(index)
                }
            }
            .id(trigger)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Each piece flies out along its own fixed direction, then drops and fades.
    private func piece(_ index: Int) -> some View {
        let angle = Double(index) / 24 * 2 * .pi + Self.jitter(index, 0) * 0.2
        let distance = 0.6 + 0.4 * abs(Self.jitter(index, 1))
        let dx = CGFloat(cos(angle) * distance) * 180 * scale
        let dy = CGFloat(sin(angle) * distance) * 120 * scale
        let color = Self.colors[index % Self.colors.count]
        let size = (10 + 6 * abs(CGFloat(Self.jitter(index, 2)))) * scale
        return CrayonSurface(index.isMultiple(of: 2) ? .circle : .roundedRect(cornerRadius: 3),
                             fill: CrayonFill(color: color, hachure: nil), marker: MarkerStyle(width: 0, roughness: 1, bowing: 1),
                             markerColor: .clear, seed: UInt32(4200 + index))
            .frame(width: size, height: size * (index.isMultiple(of: 3) ? 1.6 : 1))
            .keyframeAnimator(initialValue: ConfettiPose()) { view, pose in
                view.offset(x: dx * pose.out, y: dy * pose.out + pose.fall * 60 * scale)
                    .rotationEffect(.degrees(pose.spin * 220))
                    .opacity(pose.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.out) { CubicKeyframe(1, duration: 0.5); LinearKeyframe(1, duration: 1.0) }
                KeyframeTrack(\.fall) { LinearKeyframe(0, duration: 0.4); CubicKeyframe(1, duration: 1.1) }
                KeyframeTrack(\.spin) { LinearKeyframe(1, duration: 1.5) }
                KeyframeTrack(\.opacity) { LinearKeyframe(1, duration: 1.0); LinearKeyframe(0, duration: 0.5) }
            }
    }
}

private struct ConfettiPose {
    var out: CGFloat = 0
    var fall: CGFloat = 0
    var spin: Double = 0
    var opacity: Double = 1
}
