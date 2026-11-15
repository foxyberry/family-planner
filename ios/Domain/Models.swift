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
    /// School's own Bring (board G4, F2): checked in the window before leaving for school.
    public var bring: [ItemMission]?

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

    /// A school picked from the bundled list (S2, G7): its own hours when known (else 7:30–3:00),
    /// Arrive by at the start and Latest 10 minutes after, school days, MOE terms when it follows them.
    public init(entry: SchoolEntry) {
        let start = entry.hours?.start ?? 450
        self.init(name: entry.name, days: Weekday.schoolDays, start: start, end: entry.hours?.end ?? 900,
                  directoryID: entry.id, usesMoeTerms: entry.followsMoeTerms ?? false, arriveBy: start,
                  latest: start + 10)
    }

    /// The School slice moved on the clock (layout v37, All days): the slice starts at Arrive by (or
    /// the start without one) and ends at the end. Arrive by and the start move with the slice's
    /// start, Latest keeps its grace, and the end follows the slice's end. Per-weekday hours from the
    /// school website no longer apply once the grown-up set their own.
    public func moved(sliceStart: Int, sliceEnd: Int) -> School {
        var school = self
        let shift = sliceStart - (arriveBy ?? start)
        school.start = start + shift
        school.arriveBy = arriveBy.map { $0 + shift }
        school.latest = latest.map { $0 + shift }
        school.end = sliceEnd
        if shift != 0 || sliceEnd != end { school.dayHours = nil }
        return school
    }

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
    /// G7 "Change school": the next school and the day it starts, until that day comes.
    public var pendingSchool: PendingSchool?

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

    private enum CodingKeys: String, CodingKey { case id, name, colorIndex, age, schoolYear, school, face, pendingSchool }

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
        pendingSchool = try c.decodeIfPresent(PendingSchool.self, forKey: .pendingSchool)
    }

    /// The kid on `day`: a pending school whose start has come is the kid's school from then on.
    public func applyingPendingSchool(on day: Day) -> Kid {
        guard let pending = pendingSchool, pending.from <= day else { return self }
        var kid = self
        kid.school = pending.school
        kid.pendingSchool = nil
        return kid
    }
}

/// Spec "Where the kid goes changes": the next school (or preschool; nil = at home) and the day it
/// starts. Days before stay with the old place (the day templates are dated, so the clock follows).
public struct PendingSchool: Hashable, Codable, Sendable {
    public var school: School?
    public var from: Day

    public init(school: School?, from: Day) {
        self.school = school
        self.from = from
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
    /// Every month (board C3m, layout v39), from `from` up to and including `until`.
    case monthly(MonthlyRule, from: Day, until: Day?)

    /// A repeating item's first and last day; nil for a just-once item.
    public var range: (from: Day, until: Day?)? {
        switch self {
        case .once: nil
        case let .weekly(_, from, until), let .monthly(_, from, until): (from, until)
        }
    }

    /// The same repeat over another run (a split, an end). A just-once item stays as it is.
    public func with(from: Day, until: Day?) -> Recurrence {
        switch self {
        case .once: self
        case let .weekly(days, _, _): .weekly(days, from: from, until: until)
        case let .monthly(rule, _, _): .monthly(rule, from: from, until: until)
        }
    }

    /// Whether `day` is one of the repeat's days, leaving its run aside.
    public func pattern(on day: Day, calendar: Calendar) -> Bool {
        switch self {
        case let .once(date): date == day
        case let .weekly(days, _, _): days.contains(day.weekday(calendar))
        case let .monthly(rule, _, _): rule.matches(day, calendar: calendar)
        }
    }
}

/// Which day of each month an every-month item falls on: "2nd Sat" or "Day 14". A month without that
/// day (no 5th Saturday, no 31st) is skipped.
public enum MonthlyRule: Hashable, Codable, Sendable {
    /// The `nth` (1–5) `weekday` of the month.
    case nthWeekday(Int, Weekday)
    case dayOfMonth(Int)

    /// The two choices a first date gives: its weekday's place in the month, and its date.
    public static func nthWeekday(of day: Day, calendar: Calendar) -> MonthlyRule {
        .nthWeekday((day.day - 1) / 7 + 1, day.weekday(calendar))
    }

    public func matches(_ day: Day, calendar: Calendar) -> Bool {
        switch self {
        case let .nthWeekday(nth, weekday): day.weekday(calendar) == weekday && (day.day - 1) / 7 + 1 == nth
        case let .dayOfMonth(date): day.day == date
        }
    }
}

/// One day of an every-week item changed on its own ("This day", spec "Repeats, dates and changes"):
/// only the fields given override the series on that date. A skipped day is in `skippedDays`.
public struct DayChange: Hashable, Codable, Sendable {
    public var day: Day
    public var start: Int?
    public var end: Int?
    public var title: String?
    public var iconName: String?

    public init(day: Day, start: Int? = nil, end: Int? = nil, title: String? = nil, iconName: String? = nil) {
        self.day = day
        self.start = start
        self.end = end
        self.title = title
        self.iconName = iconName
    }

    public var isEmpty: Bool { start == nil && end == nil && title == nil && iconName == nil }
}

/// What an item that follows School does on a day without School (spec "Repeats, dates and changes",
/// No school days): it starts from Home at its own time, with its own way of going. `end` (board F4)
/// is its own end; without one it keeps the item's length.
public struct NoSchoolPlan: Hashable, Codable, Sendable {
    public var start: Int
    public var end: Int?
    public var trip: Trip?

    public init(start: Int, end: Int? = nil, trip: Trip? = nil) {
        self.start = start
        self.end = end.flatMap { $0 > start ? $0 : nil }
        self.trip = trip
    }

    /// Stored plans go through the same rule: an end not after the start is no end.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(start: try c.decode(Int.self, forKey: .start), end: try c.decodeIfPresent(Int.self, forKey: .end),
                  trip: try c.decodeIfPresent(Trip.self, forKey: .trip))
    }
}

/// How an every-week item's run ends (spec "Repeats, dates and changes", Runs). `term` is worked out
/// from the kid's school calendar each time the days are (so a calendar update moves it); `date` and
/// `count` are kept in the recurrence's `until`.
public enum RunsEnd: Hashable, Codable, Sendable {
    case term
    case date
    case count(Int)
    case none
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
    /// Things to take (spec "Event form rows", Bring): checked before leaving, up to `ItemMission.most`.
    public var bring: [ItemMission]
    /// How the run ends (Runs); nil for items saved before Runs, whose `until` decides.
    public var runsEnd: RunsEnd?
    /// Days changed on their own ("This day"), one per date.
    public var dayChanges: [DayChange]
    /// Minutes after the event it follows ("School end + 15 min", 0–60 in steps of 5).
    public var afterGap: Int
    /// An item after School on a day without School: nil skips it, a plan keeps it at a set time.
    public var noSchool: NoSchoolPlan?

    public init(id: UUID, title: String, iconName: String, audience: Audience, start: Int, end: Int,
                recurrence: Recurrence, skippedDays: Set<Day>, skipsHolidays: Bool, showsStar: Bool,
                trip: Trip? = nil, after: EventRef? = nil, bring: [ItemMission] = [], runsEnd: RunsEnd? = nil,
                dayChanges: [DayChange] = [], afterGap: Int = 0, noSchool: NoSchoolPlan? = nil) {
        self.runsEnd = runsEnd
        self.dayChanges = dayChanges
        self.afterGap = min(max(afterGap / 5 * 5, 0), 60)
        self.noSchool = after == .school ? noSchool : nil
        self.trip = after == nil ? trip : nil
        self.after = after
        self.bring = Array(bring.prefix(ItemMission.most))
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
    public var isMonthly: Bool { if case .monthly = recurrence { true } else { false } }
    /// Every week or every month: edits with This day / All days, drawn below just-once items.
    public var isRepeating: Bool { recurrence.range != nil }

    /// The weekdays of an every-week item (none for a just-once item).
    public var weeklyDays: Set<Weekday> { if case let .weekly(days, _, _) = recurrence { days } else { [] } }

    public var kind: SlotKind { isRepeating ? .afterSchool : .event }

    /// The item as it is on `day`: a day changed on its own has its own times, name or picture.
    public func on(_ day: Day) -> ScheduleItem {
        guard let change = dayChanges.first(where: { $0.day == day }) else { return self }
        var copy = self
        copy.start = change.start ?? start
        copy.end = change.end ?? end
        copy.title = change.title ?? title
        copy.iconName = change.iconName ?? iconName
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, iconName, audience, start, end, recurrence, skippedDays, skipsHolidays, showsStar, trip, after,
             bring, runsEnd, dayChanges, afterGap, noSchool
    }

    /// Items stored before Bring existed load with none. The dropped event missions (2026-11-14,
    /// keys `missionsBefore` / `missionsAfter`) are ignored when an old item loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id), title: try c.decode(String.self, forKey: .title),
                  iconName: try c.decode(String.self, forKey: .iconName),
                  audience: try c.decode(Audience.self, forKey: .audience),
                  start: try c.decode(Int.self, forKey: .start), end: try c.decode(Int.self, forKey: .end),
                  recurrence: try c.decode(Recurrence.self, forKey: .recurrence),
                  skippedDays: try c.decode(Set<Day>.self, forKey: .skippedDays),
                  skipsHolidays: try c.decode(Bool.self, forKey: .skipsHolidays),
                  showsStar: try c.decode(Bool.self, forKey: .showsStar),
                  trip: try c.decodeIfPresent(Trip.self, forKey: .trip),
                  after: try c.decodeIfPresent(EventRef.self, forKey: .after),
                  bring: try c.decodeIfPresent([ItemMission].self, forKey: .bring) ?? [],
                  runsEnd: try c.decodeIfPresent(RunsEnd.self, forKey: .runsEnd),
                  dayChanges: try c.decodeIfPresent([DayChange].self, forKey: .dayChanges) ?? [],
                  afterGap: try c.decodeIfPresent(Int.self, forKey: .afterGap) ?? 0,
                  noSchool: try c.decodeIfPresent(NoSchoolPlan.self, forKey: .noSchool))
    }
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
    /// School: it cannot be made free time in the day editor (its edges move since layout v37).
    public var isLocked: Bool
    /// An outing has a trip (the school block, by bus in the seed).
    public var trip: Trip?
    /// Board G1g: skipped on this day's own template. It stays on the editor clock, faded, and is
    /// free time everywhere else (home, the hub, missions).
    public var isSkipped: Bool

    public init(title: String, iconName: String, kind: SlotKind, start: Int, end: Int, isLocked: Bool = false,
                trip: Trip? = nil, isSkipped: Bool = false) {
        self.trip = trip
        self.isSkipped = isSkipped
        self.title = title
        self.iconName = iconName
        self.kind = kind
        self.start = start
        self.end = end
        self.isLocked = isLocked
    }

    private enum CodingKeys: String, CodingKey { case title, iconName, kind, start, end, isLocked, trip, isSkipped }

    /// Templates saved before G1g have no `isSkipped`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(title: try c.decode(String.self, forKey: .title), iconName: try c.decode(String.self, forKey: .iconName),
                  kind: try c.decode(SlotKind.self, forKey: .kind), start: try c.decode(Int.self, forKey: .start),
                  end: try c.decode(Int.self, forKey: .end), isLocked: try c.decode(Bool.self, forKey: .isLocked),
                  trip: try c.decodeIfPresent(Trip.self, forKey: .trip),
                  isSkipped: try c.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false)
    }
}

/// One kid's day template for one day type, used from `from` until a newer template of the same type starts.
/// With `onlyOn` it is that one day's own template (G1 "This day"): it wins over the day type's
/// template on that date and nowhere else.
public struct Routine: Hashable, Codable, Sendable {
    public var kid: Kid.ID
    public var dayType: DayType
    public var from: Day
    public var blocks: [RoutineBlock]
    public var onlyOn: Day?

    public init(kid: Kid.ID, dayType: DayType, from: Day, blocks: [RoutineBlock], onlyOn: Day? = nil) {
        self.kid = kid
        self.dayType = dayType
        self.from = from
        self.blocks = blocks
        self.onlyOn = onlyOn
    }

    /// One day's own template (spec "Edit scope", This day).
    public static func day(_ day: Day, kid: Kid.ID, dayType: DayType, blocks: [RoutineBlock]) -> Routine {
        Routine(kid: kid, dayType: dayType, from: day, blocks: blocks, onlyOn: day)
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
