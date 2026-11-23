import Foundation

/// A −/+ value's limits on a grown-up form: the reducer clamps to them, and a − or + whose end the
/// value sits on draws the 40 % off look (design decision, 2026-11-22).
public struct StepRange: Equatable, Sendable {
    public let bounds: ClosedRange<Int>

    public init(_ bounds: ClosedRange<Int>) {
        self.bounds = bounds
    }

    /// Walk to the stop (C2, S3): 0–60 minutes.
    public static let walk = StepRange(0...60)
    /// A bus ride (C2, C2c Ride 1 and 2, S3): 0–90 minutes.
    public static let ride = StepRange(0...90)
    /// Late grace after arrive-by (C2): 0–30 minutes.
    public static let lateGrace = StepRange(0...30)
    /// The wait between two buses (C2c): 0–30 minutes.
    public static let change = StepRange(0...30)
    /// Leave before a walk or a car ride (item form, S3): 0–90 minutes.
    public static let leave = StepRange(0...90)
    /// Starts after the event it follows (item form): 0–60 minutes.
    public static let afterGap = StepRange(0...60)
    /// The way home's minutes ("Takes", board F7): 0–90.
    public static let homeAfter = StepRange(0...90)
    /// Runs for {n} times (item form): 1–40.
    public static let times = StepRange(1...40)

    public func clamp(_ value: Int) -> Int { min(max(value, bounds.lowerBound), bounds.upperBound) }

    /// Which way `value` can still move.
    public func ends(_ value: Int) -> StepEnds {
        StepEnds(canLower: value > bounds.lowerBound, canRaise: value < bounds.upperBound)
    }
}

/// Whether a stepper's − and + can still be pressed.
public struct StepEnds: Equatable, Sendable {
    public var canLower: Bool
    public var canRaise: Bool

    public init(canLower: Bool, canRaise: Bool) {
        self.canLower = canLower
        self.canRaise = canRaise
    }
}
