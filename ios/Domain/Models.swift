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

    public init(title: String, iconName: String, kind: SlotKind, start: Int, end: Int, isLocked: Bool = false) {
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
