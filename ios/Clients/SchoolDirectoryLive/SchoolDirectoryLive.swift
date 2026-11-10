import Dependencies
import Domain
import Foundation
import SchoolDirectory

extension SchoolDirectory {
    /// The bundled lists (`Resources/`, see `SOURCE.md`): every MOE school from data.gov.sg with the
    /// hours the school websites state, and, when a developer's machine has it, the git-ignored
    /// international list (`Private/`, licence not decided yet).
    public static let live: SchoolDirectory = {
        let lists = BundledSchools.load()
        return SchoolDirectory(schools: { lists.schools }, sources: { lists.sources }, calendar: { school, age in
            @Dependency(\.calendar) var calendar
            return lists.calendars(calendar).calendar(for: school, age: age)
        })
    }()
}

enum BundledSchools {
    struct Lists: Sendable {
        var schools: [SchoolEntry]
        var sources: [DataSource]
        /// The school calendars for the app's calendar (read at call time).
        var calendars: @Sendable (Calendar) -> SchoolCalendars = { _ in
            SchoolCalendars(moeLevels: [:], own: [:], moe: { _ in .none })
        }
    }

    static func load() -> Lists {
        let hours = decode(HoursFile.self, "school-hours", from: publicBundle)?.schools ?? [:]
        guard let moe = decode(MoeFile.self, "schools-sg", from: publicBundle) else { return Lists(schools: [], sources: []) }
        var schools = moe.schools.map { $0.entry(hours: hours[$0.id]?.hours) }
        let other = decode(OtherFile.self, "international-schools-sg", from: privateBundle)
        schools += other?.schools.map(\.entry) ?? []
        let sources = [moe.source, moe.geocoding].map {
            DataSource(name: $0.name, attribution: $0.attribution, licenceURL: $0.licenceUrl)
        }
        let moeCalendar = decode(MoeCalendarFile.self, "moe-calendar", from: publicBundle)
        var levels: [String: SchoolEntry.MoeLevel] = [:]
        for entry in schools { if case let .moe(level) = entry.kind { levels[entry.id] = level } }
        let moeLevels = levels
        return Lists(schools: schools, sources: sources, calendars: { calendar in
            let own = Dictionary((other?.schools ?? []).compactMap { school in
                school.calendar(calendar: calendar).map { (school.id, $0) }
            }, uniquingKeysWith: { first, _ in first })
            return SchoolCalendars(moeLevels: moeLevels, own: own,
                                   moe: { moeCalendar?.calendar($0, calendar: calendar) ?? .none })
        })
    }

    /// The highest file shape this build reads (README "Versioning").
    static let schemaVersion = 1

    static func decode<T: Decodable & Versioned>(_ type: T.Type, _ name: String, from bundle: Bundle?) -> T? {
        guard let url = bundle?.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(T.self, from: data),
              file.schemaVersion <= schemaVersion
        else { return nil }
        return file
    }

    /// "07:30" → 450.
    static func minute(_ text: String?) -> Int? {
        guard let parts = text?.split(separator: ":").compactMap({ Int($0) }), parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// "2026-11-09" → the day.
    static func day(_ text: String?) -> Day? {
        guard let parts = text?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
        return Day(year: parts[0], month: parts[1], day: parts[2])
    }

    static let publicBundle = bundle(named: "SchoolDirectoryResources") // copy-ok: bundle name
    static let privateBundle = bundle(named: "SchoolDirectoryPrivateResources") // copy-ok: bundle name

    /// Resource bundles sit next to this module's code: in the app, or in a test bundle.
    private static func bundle(named name: String) -> Bundle? {
        [Bundle(for: Token.self), .main].lazy
            .compactMap { $0.url(forResource: name, withExtension: "bundle") }
            .compactMap(Bundle.init(url:))
            .first
    }

    private final class Token {}
}

protocol Versioned { var schemaVersion: Int { get } }

// MARK: File shapes (the fields the app reads; see SOURCE.md)

struct Source: Decodable {
    let name: String
    let attribution: String
    let licenceUrl: String
}

struct MoeFile: Decodable, Versioned {
    struct School: Decodable {
        let id: String
        let name: String
        let level: String
        let hasPrimary: Bool
        let planningArea: String?
        let searchKeys: [String]

        func entry(hours: SchoolHours?) -> SchoolEntry {
            let moeLevel: SchoolEntry.MoeLevel = switch level {
            case "primary": .primary
            case "mixed_primary_secondary": .primaryAndSecondary
            default: .secondary
            }
            return SchoolEntry(id: id, name: name, kind: .moe(moeLevel), area: planningArea?.capitalized,
                               hasPrimary: hasPrimary, followsMoeTerms: true, hours: hours, searchKeys: searchKeys)
        }
    }

    let schemaVersion: Int
    let source: Source
    let geocoding: Source
    let schools: [School]
}

/// Daily hours as a school page states them: one start and end, or rows per weekday and level.
struct StatedHours: Decodable {
    struct Variant: Decodable {
        let days: [String]?
        let levels: [String]?
        let start: String?
        let end: String?
    }

    let start: String?
    let end: String?
    let variants: [Variant]?

    /// The hours for most of the week for a middle level (P3), when the page has no single value,
    /// and each weekday's own hours where they differ from those.
    func hours(checked: Day?) -> SchoolHours? {
        let rows = variants ?? []
        let usual = rows.max { Self.score($0) < Self.score($1) }
        guard let checked,
              let start = BundledSchools.minute(start) ?? BundledSchools.minute(usual?.start) else { return nil }
        let end = BundledSchools.minute(end) ?? BundledSchools.minute(usual?.end)
        var byWeekday: [Weekday: SchoolDayHours] = [:]
        for (code, weekday) in Self.weekdays {
            let row = rows.filter { ($0.days ?? []).contains(code) || ($0.days ?? []).contains("daily") }
                .max { Self.levelScore($0) < Self.levelScore($1) }
            guard let row, let dayStart = BundledSchools.minute(row.start) ?? Optional(start),
                  let dayEnd = BundledSchools.minute(row.end) ?? end,
                  dayStart != start || dayEnd != end else { continue }
            byWeekday[weekday] = SchoolDayHours(weekday: weekday, start: dayStart, end: dayEnd)
        }
        return SchoolHours(start: start, end: end, checked: checked, byWeekday: byWeekday)
    }

    private static let weekdays: [(String, Weekday)] = [
        ("mon", .monday), ("tue", .tuesday), ("wed", .wednesday), ("thu", .thursday), ("fri", .friday),
    ]

    private static func levelScore(_ row: Variant) -> Int {
        let levels = row.levels ?? []
        return levels.isEmpty || levels.contains { $0 == "P3" || $0 == "primary" } ? 1 : 0
    }

    private static func score(_ row: Variant) -> Int { (row.days?.count ?? 0) * 10 + levelScore(row) * 5 }
}

struct HoursFile: Decodable, Versioned {
    struct School: Decodable {
        let status: String
        let start: String?
        let end: String?
        let variants: [StatedHours.Variant]?
        let checkedAt: String?

        /// Only what the school website states (status found or partial).
        var hours: SchoolHours? {
            guard status == "found" || status == "partial" else { return nil }
            return StatedHours(start: start, end: end, variants: variants).hours(checked: BundledSchools.day(checkedAt))
        }
    }

    let schemaVersion: Int
    let schools: [String: School]
}

struct OtherFile: Decodable, Versioned {
    struct School: Decodable {
        struct TermYear: Decodable {
            let terms: [Range]?
            let breaksAndHolidays: [Range]?
        }

        /// A term or a break from the school's website (inclusive dates).
        struct Range: Decodable {
            let name: String
            let start: String?
            let end: String?
        }

        let id: String
        let name: String
        let levels: [String]
        let curriculum: [String]?
        let followsMoeTerms: Bool?
        let termDates: [TermYear]?
        let dailyHours: StatedHours?
        let checkedAt: String?
        let searchKeys: [String]

        var entry: SchoolEntry {
            SchoolEntry(id: id, name: name, kind: .other(curriculum: curriculum?.first), area: nil,
                        hasPrimary: levels.contains("primary"), followsMoeTerms: followsMoeTerms,
                        hours: dailyHours?.hours(checked: BundledSchools.day(checkedAt)),
                        breakCount: (termDates?.first?.breaksAndHolidays ?? []).count, searchKeys: searchKeys)
        }
    }

    let schemaVersion: Int
    let schools: [School]
}
