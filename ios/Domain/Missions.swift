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
    /// The weekdays it is on (spec C5 "days per mission"): every day unless the grown-up picks fewer.
    public var days: Set<Weekday>

    public init(id: UUID, kid: Kid.ID, name: String, picture: String, order: Int,
                days: Set<Weekday> = Set(Weekday.allCases)) {
        self.id = id
        self.kid = kid
        self.name = String(name.prefix(Self.longestName))
        self.picture = picture
        self.order = order
        self.days = days
    }

    private enum CodingKeys: String, CodingKey { case id, kid, name, picture, order, days }

    /// Missions stored before days existed are on every day.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id), kid: try c.decode(Kid.ID.self, forKey: .kid),
                  name: try c.decode(String.self, forKey: .name), picture: try c.decode(String.self, forKey: .picture),
                  order: try c.decode(Int.self, forKey: .order),
                  days: try c.decodeIfPresent(Set<Weekday>.self, forKey: .days) ?? Set(Weekday.allCases))
    }
}

/// A mission or a thing to bring on an item (spec "Event form rows"): a picture and a short name,
/// at most `most` per list.
public struct ItemMission: Identifiable, Hashable, Codable, Sendable {
    public static let most = 4

    public var id: UUID
    public var name: String
    /// A `KitSlot` raw value.
    public var picture: String

    public init(id: UUID, name: String, picture: String) {
        self.id = id
        self.name = String(name.prefix(Mission.longestName))
        self.picture = picture
    }
}

/// An event a trip, a route or a record can point at (spec "Events: one shape for every item"): the
/// kid's School block, or an every-week or just-once item. Other template blocks have no id yet.
public enum EventRef: Hashable, Codable, Sendable {
    case school
    case item(ScheduleItem.ID)

    /// The event a slot of the day comes from, if it can be pointed at.
    public init?(_ slot: Slot) {
        switch slot.source {
        case .routine: if slot.kind == .school { self = .school } else { return nil }
        case let .weekly(id), let .once(id): self = .item(id)
        }
    }
}

/// When missions show (spec "Mission windows"): the morning routine, before or after an outing, and
/// the evening routine.
public enum MissionWindow: Hashable, Codable, Sendable {
    case morning
    case before(EventRef)
    case after(EventRef)
    case evening
}

/// The missions a kid has done in one window of one date (spec "Slide to go and done state").
public struct WindowMissions: Hashable, Codable, Sendable {
    public var kid: Kid.ID
    public var date: Day
    public var window: MissionWindow
    public var done: Set<Mission.ID>

    public init(kid: Kid.ID, date: Day, window: MissionWindow, done: Set<Mission.ID> = []) {
        self.kid = kid
        self.date = date
        self.window = window
        self.done = done
    }
}

/// A kid's slide for one outing of one date: ready, when, and the medal. `outing` nil is the morning's
/// "All done? Slide!" on a day with no outing, which has no medal.
public struct OutingSlide: Hashable, Codable, Sendable {
    public var kid: Kid.ID
    public var date: Day
    public var outing: EventRef?
    public var ready: Bool
    public var readyAt: Int?
    public var medal: MorningMedal?

    public init(kid: Kid.ID, date: Day, outing: EventRef?, ready: Bool = false, readyAt: Int? = nil,
                medal: MorningMedal? = nil) {
        self.kid = kid
        self.date = date
        self.outing = outing
        self.ready = ready
        self.readyAt = readyAt
        self.medal = medal
    }
}

/// The morning screen's view of one kid's date: the morning window's missions with the slide of the
/// day's first outing. Not stored: the store keeps `WindowMissions` and `OutingSlide`, 14 days each.
public struct MissionDay: Hashable, Codable, Sendable {
    public static let kept = 14

    public var kid: Kid.ID
    public var date: Day
    public var done: Set<Mission.ID>
    public var ready: Bool
    /// When the kid slid to go (minutes after midnight); nil before, and for "All done!" kids.
    public var readyAt: Int?
    /// The medal from that time (spec "Medal from the time only"); nil until the kid slides.
    public var medal: MorningMedal?

    public init(kid: Kid.ID, date: Day, done: Set<Mission.ID> = [], ready: Bool = false, readyAt: Int? = nil,
                medal: MorningMedal? = nil) {
        self.kid = kid
        self.date = date
        self.done = done
        self.ready = ready
        self.readyAt = readyAt
        self.medal = medal
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
}
