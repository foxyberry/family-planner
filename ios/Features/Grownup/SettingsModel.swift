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

/// Where a Settings row goes. Rows without a screen yet (Age, Face, School, Hours, Terms) have none.
public enum SettingsLink: Equatable, Sendable {
    case buses
    case missions
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
                                today: Day, calendar: Calendar) -> [SettingsSection] {
        var sections = [SettingsSection(title: L10n.tr("settings.about"), rows: [
            SettingsRow(key: L10n.tr("settings.age"), value: age(kid)),
            SettingsRow(key: L10n.tr("settings.face"), picture: kid.face, value: colourName(kid.colorIndex)),
        ])]
        if let school = kid.school {
            var rows = [
                SettingsRow(key: L10n.tr("settings.school"), picture: "actSchool", value: school.name), // copy-ok: a KitSlot name
                SettingsRow(key: L10n.tr("settings.hours"),
                            value: L10n.tr("settings.hours.value",
                                           school.days == Weekday.schoolDays ? L10n.tr("settings.hours.weekdays")
                                               : DayText.chips(school.days),
                                           TimeText.hours(school.start, school.end))),
            ]
            if let terms = terms(schoolYear, today: today, dayCalendar: calendar) {
                rows.append(SettingsRow(key: L10n.tr("settings.terms"), value: terms))
            }
            sections.append(SettingsSection(title: L10n.tr("settings.school"), rows: rows))
            let buses = busPlan.map { L10n.tr("hub.more.buses.value", $0.services.joined(separator: ", "), $0.walk) }
                ?? L10n.tr("hub.more.buses.none")
            sections.append(SettingsSection(title: L10n.tr("settings.getting_there"), rows: [
                SettingsRow(key: L10n.tr("settings.to_school"), picture: busPlan == nil ? nil : "busDouble", // copy-ok: a KitSlot name
                            value: buses, link: .buses),
            ]))
        }
        let own = missions.filter { $0.kid == kid.id }.count
        sections.append(SettingsSection(title: L10n.tr("settings.routines"), rows: [
            SettingsRow(key: L10n.tr("settings.missions"), picture: "sun", // copy-ok: a KitSlot name
                        value: L10n.tr("settings.missions.morning", own), link: .missions),
        ]))
        return sections
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
