import SwiftUI

/// The kid screens' day or night look (board A1n). Views read their colours from here, so the
/// look is decided once in State and the view only renders it.
public enum KidLook: String, Equatable, Sendable {
    case day, night

    public var page: Color { self == .day ? CrayonColor.paper : CrayonColor.night }
    public var ink: Color { self == .day ? CrayonColor.ink : CrayonColor.nightText }
    public var softText: Color { self == .day ? CrayonColor.softText : CrayonColor.nightSoftText }
    /// Clock hour labels: the four main ones, then the rest.
    public var majorLabel: Color { self == .day ? CrayonColor.ink : CrayonColor.nightText }
    public var minorLabel: Color { self == .day ? CrayonColor.softText : CrayonColor.nightSoftText }
    /// Hour ticks and the clock's outer ring: marker by day, chalk at night.
    public var tick: Color { self == .day ? CrayonColor.marker : CrayonColor.nightText }
    /// The clock face under the slots: page paper by day, a lit paper face at night.
    public var clockFace: Color { self == .day ? CrayonColor.paper : CrayonColor.litPaper }

    /// A kid's colour: the same by day and night (board 00).
    public func kid(_ colorIndex: Int) -> Color { CrayonColor.kid(colorIndex) }

    /// The 2 s crossfade between the looks (Reduce Motion keeps a fade too).
    public static let crossfade = Animation.easeInOut(duration: 2)
}
