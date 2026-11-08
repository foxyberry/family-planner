import CrayonKit
import SwiftUI

/// Colours of the 24-hour clock's slots (board A1). The hatch angles differ so neighbours read apart.
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
        return CrayonFill(color: rgb.color, hachure: HachureStyle(degrees: degrees))
    }
}
