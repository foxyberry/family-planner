import Domain
import Foundation
import Strings

/// One line of Settings (board G6): the label, the value (with an optional picture before it, a
/// `KitSlot` raw value) and where it goes, if anywhere.
public struct SettingsRow: Equatable, Sendable {
    public var key: String
    public var picture: String?
    public var value: String
    public var link: SettingsLink?

    public init(key: String, picture: String? = nil, value: String, link: SettingsLink? = nil) {
        self.key = key
        self.picture = picture
        self.value = value
        self.link = link
    }
}

/// Where a Settings row goes (board G6: every row with "›"). Age and Face have no screen yet.
public enum SettingsLink: Equatable, Sendable {
    case buses
    case missions
    /// School, Hours and Terms open G4 (spec "G4 row destinations").
    case school
    /// A kid with no school yet (at home): G7 to pick a place (spec "adding a place later").
    case changeSchool
    /// A waiting hours change: G4 on the waiting hours, with "Cancel this change".
    case waitingHours
}

/// A titled block of a kid's Settings tab.
public struct SettingsSection: Equatable, Sendable {
    public var title: String
    public var rows: [SettingsRow]

    public init(title: String, rows: [SettingsRow]) {
        self.title = title
        self.rows = rows
    }
}

/// The text of Settings (board G6, spec "Grown-up mode").
public enum SettingsModel {
    /// About, then School and Getting there for a kid with a school, then Routines.
    public static func sections(kid: Kid, missions: [Mission], busPlan: BusPlan?, schoolYear: SchoolCalendar,
                                today: Day, calendar: Calendar, routines: [Routine] = []) -> [SettingsSection] {
        var sections = [SettingsSection(title: L10n.tr("settings.about"), rows: [
            SettingsRow(key: L10n.tr("settings.age"), value: age(kid)),
            SettingsRow(key: L10n.tr("settings.face"), picture: kid.face, value: colourName(kid.colorIndex)),
        ])]
        if let school = kid.school {
            var rows = [
                SettingsRow(key: L10n.tr("settings.school"), picture: "actSchool", value: school.name, // copy-ok: a KitSlot name
                            link: .school),
                SettingsRow(key: L10n.tr("settings.hours"), value: hours(school), link: .school),
            ]
            // Spec G5 "What Settings shows meanwhile": today's hours, then the waiting change under them.
            if let waiting = kid.pendingHours {
                rows.append(SettingsRow(key: L10n.tr("settings.pending.from", DayText.dayMonth(waiting.from, calendar: calendar)),
                                        value: hours(waiting.school), link: .waitingHours))
            }
            if let terms = terms(schoolYear, today: today, dayCalendar: calendar) {
                rows.append(SettingsRow(key: L10n.tr("settings.terms"), value: terms, link: .school))
            }
            sections.append(SettingsSection(title: L10n.tr("settings.school"), rows: rows))
            let trip = schoolTrip(kid: kid.id, routines: routines, today: today)
            let line = going(trip: trip, plan: busPlan, school: school)
            sections.append(SettingsSection(title: L10n.tr("settings.getting_there"), rows: [
                // By bus the row opens Our buses; another way is edited on G4's Going row.
                SettingsRow(key: L10n.tr("settings.to_school"), picture: line.picture, value: line.text,
                            link: trip.map { $0.way == .bus } ?? true ? .buses : .school),
            ]))
        } else {
            // A kid at home: the School row opens G7 to add a place; a waiting change shows below it.
            var rows = [SettingsRow(key: L10n.tr("settings.school"), value: L10n.tr("settings.child.home"), link: .changeSchool)]
            if let pending = kid.pendingSchool {
                rows.append(SettingsRow(key: L10n.tr("settings.pending.from", DayText.dayMonth(pending.from, calendar: calendar)),
                                        value: pending.school?.name ?? L10n.tr("settings.child.home"), link: .changeSchool))
            }
            sections.append(SettingsSection(title: L10n.tr("settings.school"), rows: rows))
        }
        let own = missions.filter { $0.kid == kid.id }.count
        sections.append(SettingsSection(title: L10n.tr("settings.routines"), rows: [
            SettingsRow(key: L10n.tr("settings.missions"), picture: "sun", // copy-ok: a KitSlot name
                        value: L10n.tr("settings.missions.morning", own), link: .missions),
        ]))
        return sections
    }

    /// The Hours row's value: "Mon–Fri · 7:30 am – 3:00 pm", or the days as chips.
    static func hours(_ school: School) -> String {
        L10n.tr("settings.hours.value",
                school.days == Weekday.schoolDays ? L10n.tr("settings.hours.weekdays") : DayText.chips(school.days),
                TimeText.hours(school.start, school.end))
    }

    /// Boards G4/G6/G7 (v61): "Bus 12 · 34 · 56 · leave 7:05": the kid's buses in pill order, each
    /// number once (a bus that changes by its first buses; no arrow in text), and when to leave for
    /// the fastest of them (arrive-by, or the start, less the trip and the walk).
    public static func toSchool(_ plan: BusPlan, school: School) -> String {
        let fastest = plan.routes.map(\.trip).min() ?? plan.ride
        let leave = TimeText.clock((school.arriveBy ?? school.start) - fastest - plan.walk)
        return L10n.tr("settings.to_school.value", plan.numbers.joined(separator: L10n.tr("settings.to_school.join")),
                       leave)
    }

    /// The way to school on the kid's weekday template (S3 or G4's Going), if one is set.
    public static func schoolTrip(kid: Kid.ID, routines: [Routine], today: Day) -> Trip? {
        routines.filter { $0.kid == kid && $0.dayType == .weekday }
            .sorted { $0.from < $1.from }
            .last { $0.from <= today }?
            .blocks.first { $0.kind == .school }?.trip
    }

    /// G6 "To school" and G4 "Going": by bus "Bus 12 · leave 7:05" (or "Not set yet" until Our
    /// buses has a route); walk, car or taxi "Walk · leave 7:20", from the trip's leave-before.
    public static func going(trip: Trip?, plan: BusPlan?, school: School) -> (picture: String?, text: String) {
        if let trip, trip.way != .bus {
            let leave = TimeText.clock((school.arriveBy ?? school.start) - trip.leaveBefore)
            return (trip.way.moverPicture, L10n.tr("settings.to_school.way", wayName(trip.way), leave))
        }
        guard let plan else { return (nil, L10n.tr("hub.more.buses.none")) }
        return ("busDouble", toSchool(plan, school: school)) // copy-ok: a KitSlot name
    }

    static func wayName(_ way: Way) -> String {
        switch way {
        case .walk: L10n.tr("going.walk")
        case .bus: L10n.tr("going.bus")
        case .car: L10n.tr("going.car")
        case .taxi, .shuttle: L10n.tr("going.taxi")
        }
    }

    /// "7 · Primary 1", "8", or "3 · at home".
    static func age(_ kid: Kid) -> String {
        let year = kid.schoolYear?.trimmingCharacters(in: .whitespaces) ?? ""
        if kid.school == nil { return L10n.tr("hub.about.age.home", kid.age) }
        return year.isEmpty ? L10n.tr("hub.about.age.only", kid.age) : L10n.tr("hub.about.age.school", kid.age, year)
    }

    /// The S1 colour's name: blue, orange, green or purple.
    static func colourName(_ index: Int) -> String {
        switch index {
        case 0: L10n.tr("s1.colour.blue")
        case 1: L10n.tr("s1.colour.orange")
        case 2: L10n.tr("s1.colour.green")
        default: L10n.tr("s1.colour.purple")
        }
    }

    /// "MOE 2026 · Term 4 ends 20 Nov", "Term 2 ends 3 Apr", or nil without terms.
    static func terms(_ school: SchoolCalendar, today: Day, dayCalendar: Calendar) -> String? {
        guard let term = school.term(from: today) else { return nil }
        let ends = L10n.tr("settings.terms.ends", term.name, DayText.dayMonth(term.end, calendar: dayCalendar))
        return school.isMoe ? L10n.tr("settings.terms.moe", String(term.end.year), ends) : ends
    }
}
