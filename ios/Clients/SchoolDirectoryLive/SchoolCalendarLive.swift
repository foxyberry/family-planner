import Dependencies
import Domain
import Foundation

// MARK: School calendars (spec "Repeats, dates and changes")

/// `moe-calendar.json` (see SOURCE.md): the MOE terms and closures by level, every year it lists.
struct MoeCalendarFile: Decodable, Versioned {
    struct Year: Decodable {
        let events: [Event]
    }

    struct Event: Decodable {
        let type: String
        let name: String
        let date: String?
        let start: String?
        let end: String?
        let appliesTo: AppliesTo
    }

    /// "all", or the level codes an event is for.
    enum AppliesTo: Decodable {
        case all
        case levels([String])

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let levels = try? value.decode([String].self) { self = .levels(levels) } else { self = .all }
        }

        func includes(_ level: String) -> Bool {
            switch self {
            case .all: true
            case let .levels(levels): levels.contains(level)
            }
        }
    }

    /// The kinds of day a school is closed on.
    static let closures: Set<String> = ["vacation", "school_holiday", "public_holiday", "day_off_in_lieu"]

    let schemaVersion: Int
    let years: [String: Year]

    func calendar(_ level: MoeCalendarLevel, calendar: Calendar) -> SchoolCalendar {
        let events = years.values.flatMap(\.events).filter { $0.appliesTo.includes(level.rawValue) }
        let terms = events.filter { $0.type == "term" }.compactMap { event -> SchoolCalendar.Term? in
            guard let start = BundledSchools.day(event.start), let end = BundledSchools.day(event.end) else { return nil }
            return SchoolCalendar.Term(name: event.name, start: start, end: end)
        }
        let closed = events.filter { Self.closures.contains($0.type) }.flatMap { event in
            BundledSchools.days(from: event.start ?? event.date, to: event.end ?? event.date, calendar: calendar)
        }
        return SchoolCalendar(terms: terms.sorted { $0.start < $1.start }, closed: Set(closed))
    }
}

extension BundledSchools {
    /// Every day from `start` to `end`, both included.
    static func days(from start: String?, to end: String?, calendar: Calendar) -> [Day] {
        guard var next = day(start), let last = day(end), next <= last else { return [] }
        var days: [Day] = []
        while next <= last {
            days.append(next)
            next = next.adding(days: 1, calendar: calendar)
        }
        return days
    }
}

extension OtherFile.School {
    /// A school's own year (its website's terms and breaks), when the list has it.
    func calendar(calendar: Calendar) -> SchoolCalendar? {
        let years = termDates ?? []
        let terms = years.flatMap { $0.terms ?? [] }.compactMap { range -> SchoolCalendar.Term? in
            guard let start = BundledSchools.day(range.start), let end = BundledSchools.day(range.end) else { return nil }
            return SchoolCalendar.Term(name: range.name, start: start, end: end)
        }
        guard !terms.isEmpty else { return nil }
        let closed = years.flatMap { $0.breaksAndHolidays ?? [] }.flatMap {
            BundledSchools.days(from: $0.start, to: $0.end, calendar: calendar)
        }
        return SchoolCalendar(terms: terms.sorted { $0.start < $1.start }, closed: Set(closed))
    }
}

/// Which calendar a kid's school follows: an MOE school by its level, a school with its own term
/// dates by those, else "Use MOE school terms" (kindergarten level for a preschool), else none.
struct SchoolCalendars: Sendable {
    var moeLevels: [String: SchoolEntry.MoeLevel]
    var own: [String: SchoolCalendar]
    var moe: @Sendable (MoeCalendarLevel) -> SchoolCalendar

    func calendar(for school: School, age: Int) -> SchoolCalendar {
        if let id = school.directoryID, let level = moeLevels[id] {
            return moe(MoeCalendarLevel.level(of: level, age: age))
        }
        if let id = school.directoryID, let own = own[id] { return own }
        guard school.usesMoeTerms == true else { return .none }
        return moe(school.isPreschool ? .kindergarten : .primary)
    }
}
