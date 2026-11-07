import Foundation

public struct School: Hashable, Codable, Sendable {
    public var name: String
    public var days: Set<Weekday>
    /// Minutes after midnight.
    public var start: Int
    public var end: Int

    public init(name: String, days: Set<Weekday>, start: Int, end: Int) {
        self.name = name
        self.days = days
        self.start = start
        self.end = end
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

    public init(id: UUID, name: String, colorIndex: Int, age: Int, schoolYear: String?, school: School?) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.age = age
        self.schoolYear = schoolYear
        self.school = school
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

/// What a slot is, which decides its colour on the clock.
public enum SlotKind: String, CaseIterable, Codable, Sendable {
    case sleep, morning, school, afterSchool, play, dinner, evening, event
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

    public init(id: UUID, title: String, iconName: String, audience: Audience, start: Int, end: Int,
                recurrence: Recurrence, skippedDays: Set<Day>, skipsHolidays: Bool, showsStar: Bool) {
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

/// A school day uses the kid's weekday routine; weekends and holidays use the day-off routine.
public enum DayKind: Hashable, Codable, Sendable {
    case schoolDay, dayOff
}

public struct RoutineBlock: Hashable, Codable, Sendable {
    public var title: String
    public var iconName: String
    public var kind: SlotKind
    public var start: Int
    public var end: Int

    public init(title: String, iconName: String, kind: SlotKind, start: Int, end: Int) {
        self.title = title
        self.iconName = iconName
        self.kind = kind
        self.start = start
        self.end = end
    }
}

/// One kid's day template for one kind of day.
public struct Routine: Hashable, Codable, Sendable {
    public var kid: Kid.ID
    public var dayKind: DayKind
    public var blocks: [RoutineBlock]

    public init(kid: Kid.ID, dayKind: DayKind, blocks: [RoutineBlock]) {
        self.kid = kid
        self.dayKind = dayKind
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

    public init(title: String, iconName: String, kind: SlotKind, start: Int, end: Int, source: Source,
                showsStar: Bool) {
        self.title = title
        self.iconName = iconName
        self.kind = kind
        self.start = start
        self.end = end
        self.source = source
        self.showsStar = showsStar
    }
}
