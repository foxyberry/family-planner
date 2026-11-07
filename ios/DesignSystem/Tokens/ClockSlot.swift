import CrayonKit
import SwiftUI

/// Colours of the 24-hour clock's slots (board A1). The hatch angles differ so neighbours read apart.
public enum ClockSlotStyle: String, CaseIterable, Sendable {
    case sleep, morning, school, afterSchool, play, dinner, evening, event

    public var fill: CrayonFill {
        let (rgb, degrees): (RGB, Double) = switch self {
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
