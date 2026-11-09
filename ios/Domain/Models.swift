import Foundation

/// Where a kid goes in the day (S2 "Goes to"): a school, or a preschool or childcare.
public enum SchoolKind: String, Hashable, Codable, Sendable {
    case school, preschool
}

/// One weekday's hours (minutes after midnight); a school can differ by weekday (`School.dayHours`).
public struct SchoolDayHours: Hashable, Codable, Sendable {
    public var weekday: Weekday
    public var start: Int
    public var end: Int

    public init(weekday: Weekday, start: Int, end: Int) {
        self.weekday = weekday
        self.start = start
        self.end = end
    }
}

public struct School: Hashable, Codable, Sendable {
    public var name: String
    public var days: Set<Weekday>
    /// Minutes after midnight.
    public var start: Int
    public var end: Int
    /// The school's id in the bundled school list (`SchoolEntry.id`); nil for a name typed by hand.
    /// It stays on the iPad (spec S2: the app never sends which school was picked).
    public var directoryID: String?
    /// "Use MOE school terms for holidays" (S2).
    public var usesMoeTerms: Bool?
    /// Arrive by and Latest as the grown-up confirmed them in S2 (minutes after midnight). The late
    /// grace (Latest − Arrive by) sets the medals for every way of going (spec S1–S4).
    public var arriveBy: Int?
    public var latest: Int?
    /// nil (stored before preschools existed) is a school.
    public var kind: SchoolKind?
    /// Hours per weekday when they differ (from the school website); nil means `start`–`end` every day.
    public var dayHours: [SchoolDayHours]?

    public init(name: String, days: Set<Weekday>, start: Int, end: Int, directoryID: String? = nil,
                usesMoeTerms: Bool? = nil, arriveBy: Int? = nil, latest: Int? = nil, kind: SchoolKind? = nil,
                dayHours: [SchoolDayHours]? = nil) {
        self.name = name
        self.days = days
        self.start = start
        self.end = end
        self.directoryID = directoryID
        self.usesMoeTerms = usesMoeTerms
        self.arriveBy = arriveBy
        self.latest = latest
        self.kind = kind
        self.dayHours = dayHours
    }

    public var isPreschool: Bool { kind == .preschool }

    /// Latest − Arrive by (0–30): how late still earns Bronze. nil when either time was not entered.
    public var lateGrace: Int? {
        guard let arriveBy, let latest else { return nil }
        return min(max(latest - arriveBy, 0), 30)
    }
}

public struct Kid: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// 0 = blue (Kid A), 1 = orange (Kid B).
    public var colorIndex: Int
    public var age: Int
    public var schoolYear: String?
    /// `nil` for a child who stays at home.
    public var school: School?
    /// The kid's face picture (a `KitSlot` raw value) inside their colour ring (`KidFace`).
    /// First-run setup (M4) sets it; a kid's own drawing can take the same slot later.
    public var face: String

    public init(id: UUID, name: String, colorIndex: Int, age: Int, schoolYear: String?, school: School?,
                face: String = "kidGirl") {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.age = age
        self.schoolYear = schoolYear
        self.school = school
        self.face = face
    }

    private enum CodingKeys: String, CodingKey { case id, name, colorIndex, age, schoolYear, school, face }

    /// Kids stored before `face` existed get the seed's choice: Kid B's colour → boy face, else girl.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorIndex = try c.decode(Int.self, forKey: .colorIndex)
        age = try c.decode(Int.self, forKey: .age)
        schoolYear = try c.decodeIfPresent(String.self, forKey: .schoolYear)
        school = try c.decodeIfPresent(School.self, forKey: .school)
        face = try c.decodeIfPresent(String.self, forKey: .face) ?? (colorIndex == 1 ? "kidBoy" : "kidGirl")
    }
}

public enum Audience: Hashable, Codable, Sendable {
    case kid(Kid.ID)
    case both

    public func includes(_ kid: Kid.ID) -> Bool {
        switch self {
        case let .kid(id): id == kid
        case .both: true
        }
    }
}

public enum Recurrence: Hashable, Codable, Sendable {
    case once(Day)
    /// Every week on `days`, from `from` up to and including `until`.
    case weekly(Set<Weekday>, from: Day, until: Day?)
}

/// How a kid goes to an outing (spec "MVP data"). The mover on the way strip: walk `shoe`, bus
/// `busDouble`, car `car`, taxi `taxi`, shuttle `busShuttle` (hidden until N1b).
public enum Way: String, Codable, CaseIterable, Sendable {
    case walk, bus, car, taxi, shuttle

    public var moverPicture: String {
        switch self {
        case .walk: "shoe"
        case .bus: "busDouble"
        case .car: "car"
        case .taxi: "taxi"
        case .shuttle: "busShuttle"
        }
    }
}

/// What makes a slot or item an outing: how the kid goes and how long before the start they leave
/// (0–90 minutes in steps of 5). The start is the time at the place.
public struct Trip: Hashable, Codable, Sendable {
    public var way: Way
    public var leaveBefore: Int
    /// Minutes to get home after the end (0–90, step 5; spec "Events: one shape", Trip).
    public var homeAfter: Int
    /// The medal switch for this outing: nil is the default, on for School and off for other events.
    public var medal: Bool?
    /// Minutes after the start that still earn bronze, for events other than School (School keeps S2's).
    public var lateGrace: Int?

    public init(way: Way, leaveBefore: Int, homeAfter: Int = 0, medal: Bool? = nil, lateGrace: Int? = nil) {
        self.way = way
        self.leaveBefore = Self.minutes(leaveBefore)
        self.homeAfter = Self.minutes(homeAfter)
        self.medal = medal
        self.lateGrace = lateGrace
    }

    /// Trips stored before `homeAfter` existed load with 0.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(way: try values.decode(Way.self, forKey: .way),
                  leaveBefore: try values.decode(Int.self, forKey: .leaveBefore),
                  homeAfter: try values.decodeIfPresent(Int.self, forKey: .homeAfter) ?? 0,
                  medal: try values.decodeIfPresent(Bool.self, forKey: .medal),
                  lateGrace: try values.decodeIfPresent(Int.self, forKey: .lateGrace))
    }

    /// Whether this outing gives a medal: its own switch, else on for School only.
    public func givesMedal(isSchool: Bool) -> Bool { medal ?? isSchool }

    private static func minutes(_ value: Int) -> Int { min(max(value / 5 * 5, 0), 90) }
}

/// What a slot is, which decides its colour on the clock. `free` is free time: plain paper, no picture.
public enum SlotKind: String, CaseIterable, Codable, Sendable {
    case sleep, morning, school, afterSchool, play, dinner, evening, event, free
}

public struct ScheduleItem: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var title: String
    /// A `KitSlot` raw value.
    public var iconName: String
    public var audience: Audience
    /// Minutes after midnight, `0 <= start < end <= 1440`.
    public var start: Int
    public var end: Int
    public var recurrence: Recurrence
    public var skippedDays: Set<Day>
    public var skipsHolidays: Bool
    /// Just-once items can put a star on the clock that day.
    public var showsStar: Bool
    /// An outing has a trip (spec "MVP data"); trips come from the seed until N1.
    public var trip: Trip?
    /// "From: After {event}" (spec "Events: one shape"): the item starts when that event ends, at the
    /// same place, with no trip of its own; on a day without that event it is skipped too. nil: Home.
    public var after: EventRef?

    public init(id: UUID, title: String, iconName: String, audience: Audience, start: Int, end: Int,
                recurrence: Recurrence, skippedDays: Set<Day>, skipsHolidays: Bool, showsStar: Bool,
                trip: Trip? = nil, after: EventRef? = nil) {
        self.trip = after == nil ? trip : nil
        self.after = after
        self.id = id
        self.title = title
        self.iconName = iconName
        self.audience = audience
        self.start = start
        self.end = end
        self.recurrence = recurrence
        self.skippedDays = skippedDays
        self.skipsHolidays = skipsHolidays
        self.showsStar = showsStar
    }

    public var isWeekly: Bool { if case .weekly = recurrence { true } else { false } }

    public var kind: SlotKind { isWeekly ? .afterSchool : .event }
}

/// The three kinds of day a kid has a template for. A weekday school holiday uses `sunday`.
public enum DayType: String, Codable, CaseIterable, Sendable {
    case weekday, saturday, sunday
}

public struct RoutineBlock: Hashable, Codable, Sendable {
    public var title: String
    /// A `KitSlot` raw value; empty for free time.
    public var iconName: String
    public var kind: SlotKind
    public var start: Int
    public var end: Int
    /// A locked edge (school) cannot be dragged in the day editor.
    public var isLocked: Bool
    /// An outing has a trip (the school block, by bus in the seed).
    public var trip: Trip?

    public init(title: String, iconName: String, kind: SlotKind, start: Int, end: Int, isLocked: Bool = false,
                trip: Trip? = nil) {
        self.trip = trip
        self.title = title
        self.iconName = iconName
        self.kind = kind
        self.start = start
        self.end = end
        self.isLocked = isLocked
    }
}

/// One kid's day template for one day type, used from `from` until a newer template of the same type starts.
public struct Routine: Hashable, Codable, Sendable {
    public var kid: Kid.ID
    public var dayType: DayType
    public var from: Day
    public var blocks: [RoutineBlock]

    public init(kid: Kid.ID, dayType: DayType, from: Day, blocks: [RoutineBlock]) {
        self.kid = kid
        self.dayType = dayType
        self.from = from
        self.blocks = blocks
    }
}

/// One stretch of a kid's day as the clock shows it.
public struct Slot: Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case routine
        case weekly(ScheduleItem.ID)
        case once(ScheduleItem.ID)
    }

    public var title: String
    public var iconName: String
    public var kind: SlotKind
    public var start: Int
    public var end: Int
    public var source: Source
    public var showsStar: Bool
    public var trip: Trip?
    /// The event this slot follows ("From: After {event}"); it starts when that one ends.
    public var after: EventRef?

    public init(title: String, iconName: String, kind: SlotKind, start: Int, end: Int, source: Source,
                showsStar: Bool, trip: Trip? = nil, after: EventRef? = nil) {
        self.trip = trip
        self.after = after
        self.title = title
        self.iconName = iconName
        self.kind = kind
        self.start = start
        self.end = end
        self.source = source
        self.showsStar = showsStar
    }
}
