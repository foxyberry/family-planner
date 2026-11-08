import CoreGraphics
import Foundation

/// Where a rigged part is at a moment of its play. Every move is rigid: the part turns about its
/// origin or moves whole (the hop's 5 % landing squash and a blink are the only shape changes).
public struct RigPose: Equatable, Sendable {
    public var rotation: Double = 0
    public var offset: CGSize = .zero
    public var scaleY: Double = 1
    public var scale: Double = 1
    public var opacity: Double = 1

    public static let rest = RigPose()
}

/// The timelines of the rig moves over one play (spec: ≤ 1.2 s, then still).
public enum RigMotion {
    public static let duration: Double = 1.2

    /// The pose of a part with `moves` at `time` seconds into the play. `scale` multiplies the
    /// rock, bob, slide, rise, fall, press and hop amounts; spin, blink, flicker and twinkle ignore it.
    /// Every move is back at rest at 0 and at `duration`.
    public static func pose(_ moves: [KitRig.Move], at time: Double, scale: Double) -> RigPose {
        let t = min(max(time, 0), duration)
        let p = t / duration
        var pose = RigPose.rest
        for move in moves {
            switch move {
            case let .rock(degrees, times):
                pose.rotation += degrees * scale * sin(2 * .pi * Double(times) * p)
            case let .bob(units, times):
                pose.offset.height -= units * scale * abs(sin(.pi * Double(times) * p))
            case let .slide(units, times):
                pose.offset.width += units * scale * sin(2 * .pi * Double(times) * p)
            case let .rise(units):
                pose.offset.height -= units * scale * sin(.pi * p)
            case let .fall(units):
                pose.offset.height += units * scale * sin(.pi * p)
            case let .press(units, delay):
                let start = delay / 1000, length = 0.4
                if t >= start, t <= start + length {
                    pose.offset.height += units * scale * sin(.pi * (t - start) / length)
                }
            case let .spin(degrees):
                pose.rotation += degrees * easeInOut(p)
            case .blink:
                if p >= 0.4, p <= 0.6 { pose.scaleY *= 1 - 0.85 * sin(.pi * (p - 0.4) / 0.2) }
            case .flicker:
                pose.opacity *= 1 - 0.4 * pow(sin(3 * .pi * p), 2)
            case .twinkle:
                pose.scale *= 1 + 0.2 * sin(.pi * p)
            case let .hop(units):
                if p <= 0.8 {
                    pose.offset.height -= units * scale * sin(.pi * p / 0.8)
                } else {
                    pose.scaleY *= 1 - 0.05 * sin(.pi * (p - 0.8) / 0.2)
                }
            }
        }
        return pose
    }

    private static func easeInOut(_ p: Double) -> Double { p * p * (3 - 2 * p) }
}
