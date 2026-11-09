import CrayonKit
import SwiftUI

/// Colours of the 24-hour clock's slots (board A1): long hachure at about −50°, nudged per slot.
/// Free time has no fill: plain paper between its radial edges.
public enum ClockSlotStyle: String, CaseIterable, Sendable {
    case sleep, morning, school, afterSchool, play, dinner, evening, event, free

    public var fill: CrayonFill? {
        if self == .free { return nil }
        let (rgb, degrees): (RGB, Double) = switch self {
        case .free: (CrayonPalette.green, 0)
        case .sleep: (CrayonPalette.goYellow, -40)
        case .morning: (CrayonPalette.mint, 60)
        case .school: (CrayonPalette.orange, -55)
        case .afterSchool: (CrayonPalette.nowSky, 40)
        case .play: (CrayonPalette.green, -30)
        case .dinner: (CrayonPalette.coral, 50)
        case .evening: (CrayonPalette.lilac, -60)
        case .event: (CrayonPalette.pink, 50)
        }
        // Spec "Clock fill" (boards A1/E3, 2026-11-09): a light wash with long parallel strokes at
        // about −50°, paper showing between them; each slot leans a few degrees its own way.
        return CrayonFill(color: rgb.color,
                          hachure: HachureStyle(degrees: -50 + degrees / 12, gap: 9, weight: 4, washOpacity: 0.22,
                                                strokeLength: 220...420, bendRadius: 1600, taper: 0.45,
                                                edgeJitter: 0.4, angleJitter: 2))
    }
}
