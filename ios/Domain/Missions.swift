import Foundation

/// A morning mission (spec "MVP data"): one circle on the kid's morning screen. Morning only, at
/// most `Mission.most` a kid, names at most `Mission.longestName` characters (C5).
public struct Mission: Identifiable, Hashable, Codable, Sendable {
    public static let most = 8
    public static let longestName = 14

    public var id: UUID
    public var kid: Kid.ID
    public var name: String
    /// A `KitSlot` raw value.
    public var picture: String
    public var order: Int

    public init(id: UUID, kid: Kid.ID, name: String, picture: String, order: Int) {
        self.id = id
        self.kid = kid
        self.name = String(name.prefix(Self.longestName))
        self.picture = picture
        self.order = order
    }
}

/// A kid's mission marks for one date (spec "MVP data"): which missions are done and whether the
/// kid tapped "All done!". A new date starts empty at midnight; the store keeps 14 days.
public struct MissionDay: Hashable, Codable, Sendable {
    public static let kept = 14

    public var kid: Kid.ID
    public var date: Day
    public var done: Set<Mission.ID>
    public var ready: Bool

    public init(kid: Kid.ID, date: Day, done: Set<Mission.ID> = [], ready: Bool = false) {
        self.kid = kid
        self.date = date
        self.done = done
        self.ready = ready
    }
}

/// The next outing of a kid's day: a slot with a trip that has not started yet.
public struct Outing: Equatable, Sendable {
    public var slot: Slot
    public var trip: Trip
    /// The minute to leave home: start − leaveBefore.
    public var leave: Int { slot.start - trip.leaveBefore }

    public init(slot: Slot, trip: Trip) {
        self.slot = slot
        self.trip = trip
    }
}

public extension DayPlanner {
    /// The kid's next outing today (spec "MVP data"): the first slot with a trip that starts after
    /// `minute`. An outing that has started is over for the morning screen.
    static func nextOuting(in slots: [Slot], after minute: Int) -> Outing? {
        slots.sorted { $0.start < $1.start }
            .first { $0.trip != nil && $0.start > minute }
            .flatMap { slot in slot.trip.map { Outing(slot: slot, trip: $0) } }
    }

    /// Spec A1 "Mission morning": from the earliest kid's wake-up (the end of their sleep that starts
    /// at midnight) until 12:00 pm.
    static func isMissionMorning(at minute: Int, wakes: [Int]) -> Bool {
        guard let earliest = wakes.min() else { return false }
        return minute >= earliest && minute < 720
    }
}
