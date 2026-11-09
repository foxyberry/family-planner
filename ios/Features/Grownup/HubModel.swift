import Domain
import Foundation
import Strings

public struct HubRow: Equatable, Sendable {
    /// A piece of the value: an optional picture (a `KitSlot` raw value) before its words.
    public struct Part: Equatable, Sendable {
        public var picture: String?
        public var text: String

        public init(picture: String? = nil, text: String) {
            self.picture = picture
            self.text = text
        }
    }

    public var key: String
    public var parts: [Part]
    /// The words alone ("Up 6:30 am · Bed 8:00 pm"), for VoiceOver and tests.
    public var value: String { parts.map(\.text).joined(separator: " ") }

    public init(key: String, value: String) {
        self.key = key
        parts = [Part(text: value)]
    }

    public init(key: String, parts: [Part]) {
        self.key = key
        self.parts = parts
    }
}

/// C1's side "More" row (board C1): the sun picture, "Morning missions" over the count, to C5.
public struct HubMoreRow: Equatable, Sendable {
    public var picture: String
    public var title: String
    public var caption: String

    public init(picture: String, title: String, caption: String) {
        self.picture = picture
        self.title = title
        self.caption = caption
    }
}

/// A titled block of the About card. The school's days are their own row kind, drawn as day chips.
public struct HubSection: Equatable, Sendable {
    public enum Row: Equatable, Sendable {
        case text(HubRow)
        case schoolDays(key: String, days: Set<Weekday>)
        /// A row that opens a screen: "Day" opens C6 Our day, "Morning missions" and "Cards" open C5.
        case link(HubRow, to: HubLink)
    }

    public var title: String
    public var rows: [Row]

    public init(title: String, rows: [Row]) {
        self.title = title
        self.rows = rows
    }
}

/// Where a hub link row goes.
public enum HubLink: Equatable, Sendable {
    case day
    case missions
    case buses
}

public struct HubItemRow: Equatable, Identifiable, Sendable {
    public var id: ScheduleItem.ID
    public var iconName: String
    public var title: String
    /// "Mon · Wed" or "Sat 14 Nov".
    public var when: String
    /// "3:30–4:30 pm".
    public var time: String
    /// One line: "Mon · Wed 3:30–4:30 pm", "Sat 14 Nov · 2:00–4:00 pm".
    public var detail: String

    public init(id: ScheduleItem.ID, iconName: String, title: String, when: String, time: String, separator: String) {
        self.id = id
        self.iconName = iconName
        self.title = title
        self.when = when
        self.time = time
        detail = when + separator + time
    }
}

/// The text of the Our kids hub (boards C1, E6).
public enum HubModel {
    /// About, then School and More for a school kid, or Nursery and Morning for a kid at home.
    /// `missions` are every kid's; the kid's own count or names go on the C5 link row.
    public static func sections(kid: Kid, routines: [Routine], missions: [Mission] = [],
                                busPlan: BusPlan? = nil) -> [HubSection] {
        let about = HubSection(title: L10n.tr("hub.about"), rows: aboutRows(kid: kid, routines: routines).map { row in
            row.key == L10n.tr("hub.about.day") ? .link(row, to: .day) : .text(row)
        })
        let own = missions.filter { $0.kid == kid.id }.sorted { $0.order < $1.order }
        guard let school = kid.school else {
            let cards = own.isEmpty ? L10n.tr("hub.empty") : own.map(\.name).joined(separator: " · ")
            return [about,
                    HubSection(title: L10n.tr("hub.nursery"),
                               rows: [.text(HubRow(key: L10n.tr("hub.nursery"), value: L10n.tr("hub.nursery.not_yet")))]),
                    HubSection(title: L10n.tr("hub.morning"),
                               rows: [.link(HubRow(key: L10n.tr("hub.morning.cards"), value: cards), to: .missions),
                                      .text(HubRow(key: L10n.tr("hub.morning.taps"),
                                                   value: L10n.tr("hub.morning.taps.value")))])]
        }
        var rows = schoolRows(kid: kid).map(HubSection.Row.text)
        rows.insert(.schoolDays(key: L10n.tr("hub.school.days"), days: school.days), at: 1)
        // C1 "Getting there" → C2 (spec "Bus settings"): the kid's buses and walk, or "Not set yet".
        // Board C1 has it last in the School card; "More" moved to the side column (`moreRow`).
        let buses = busPlan.map { L10n.tr("hub.more.buses.value", $0.services.joined(separator: ", "), $0.walk) }
            ?? L10n.tr("hub.more.buses.none")
        let gettingThere = HubSection(title: L10n.tr("hub.more.buses"),
                                      rows: [.link(HubRow(key: L10n.tr("hub.getting.to_school"), value: buses), to: .buses)])
        return [about, HubSection(title: L10n.tr("hub.school"), rows: rows), gettingThere]
    }

    /// Board C1's side "More" for a school kid: "Morning missions" over the kid's count. A kid at
    /// home has the Morning section in the card instead.
    public static func moreRow(kid: Kid, missions: [Mission]) -> HubMoreRow? {
        guard kid.school != nil else { return nil }
        let own = missions.filter { $0.kid == kid.id }.count
        let count = switch own {
        case 0: L10n.tr("hub.empty")
        case 1: L10n.tr("hub.more.missions.one")
        default: L10n.tr("hub.more.missions.count", own)
        }
        return HubMoreRow(picture: "sun", title: L10n.tr("hub.more.missions"), caption: count) // copy-ok: a KitSlot name
    }

    /// The heading over the every-week items.
    public static func weeklyHeading(kid: Kid) -> String {
        kid.school == nil ? L10n.tr("hub.weekly.every_week") : L10n.tr("hub.weekly.after_school")
    }

    public static func aboutRows(kid: Kid, routines: [Routine]) -> [HubRow] {
        // The newest Mon–Fri template: the kid's usual school-day rhythm.
        let blocks = routines.filter { $0.kid == kid.id && $0.dayType == .weekday }
            .max { $0.from < $1.from }?.blocks ?? []
        let sleeps = blocks.filter { $0.kind == .sleep }
        let wake = sleeps.first { $0.start == 0 }?.end
        let bed = sleeps.first { $0.end == 1440 }?.start
        let nap = sleeps.first { $0.start != 0 && $0.end != 1440 }
        let year = kid.schoolYear?.trimmingCharacters(in: .whitespaces) ?? ""
        let age = kid.school == nil ? L10n.tr("hub.about.age.home", kid.age)
            : year.isEmpty ? L10n.tr("hub.about.age.only", kid.age) : L10n.tr("hub.about.age.school", kid.age, year)
        // Board C1: the sun before "Up", the moon before "Nap" and "Bed"; " ·" ends all but the last.
        var day: [HubRow.Part] = []
        if kid.school != nil, let wake { day.append(HubRow.Part(picture: "sun", text: L10n.tr("hub.about.up", TimeText.withPeriod(wake)))) } // copy-ok: a KitSlot name
        if let nap { day.append(HubRow.Part(picture: "actSleep", text: L10n.tr("hub.about.nap", TimeText.range(nap.start, nap.end)))) } // copy-ok: a KitSlot name
        if let bed { day.append(HubRow.Part(picture: "actSleep", text: L10n.tr("hub.about.bed", TimeText.withPeriod(bed)))) } // copy-ok: a KitSlot name
        for index in day.indices.dropLast() { day[index].text = L10n.tr("hub.about.part", day[index].text) }
        return [HubRow(key: L10n.tr("hub.about.age"), value: age),
                HubRow(key: L10n.tr("hub.about.day"), parts: day)]
    }

    /// School name, hours and holidays (`sections` adds the school days after the name).
    public static func schoolRows(kid: Kid) -> [HubRow] {
        guard let school = kid.school else { return [] }
        return [
            HubRow(key: L10n.tr("hub.school"), parts: [HubRow.Part(picture: "actSchool", text: school.name)]), // copy-ok: a KitSlot name
            HubRow(key: L10n.tr("hub.school.hours"), value: TimeText.hours(school.start, school.end)),
            HubRow(key: L10n.tr("hub.school.holidays"), value: L10n.tr("hub.school.no_holidays")),
        ]
    }

    /// Every-week items for `kid` that are still running (stopped or replaced series stay in past days only).
    public static func weeklyRows(kid: Kid, items: [ScheduleItem]) -> [HubItemRow] {
        items.compactMap { item -> (ScheduleItem, Set<Weekday>)? in
            guard item.audience.includes(kid.id), case let .weekly(days, _, until) = item.recurrence, until == nil
            else { return nil }
            return (item, days)
        }
        .sorted { ($0.0.start, $0.0.title) < ($1.0.start, $1.0.title) }
        .map { item, days in
            HubItemRow(id: item.id, iconName: item.iconName, title: item.title, when: DayText.chips(days),
                       time: TimeText.range(item.start, item.end), separator: " ")
        }
    }

    /// Upcoming just-once items for `kid`, nearest first, at most five. An item stays listed until the
    /// kid's next wake-up after its day.
    public static func onceRows(kid: Kid, items: [ScheduleItem], routines: [Routine], today: Day, nowMinute: Int,
                                calendar: Calendar) -> [HubItemRow] {
        let wake = DayPlanner.template(for: kid.id, on: today, routines: routines, holidays: [], calendar: calendar)?.blocks
            .first { $0.kind == .sleep && $0.start == 0 }?.end ?? 0
        let yesterday = today.adding(days: -1, calendar: calendar)
        return items.compactMap { item -> (ScheduleItem, Day)? in
            guard item.audience.includes(kid.id), case let .once(day) = item.recurrence else { return nil }
            guard day >= today || (day == yesterday && nowMinute < wake) else { return nil }
            return (item, day)
        }
        .sorted { ($0.1, $0.0.start) < ($1.1, $1.0.start) }
        .prefix(5)
        .map { item, day in
            HubItemRow(id: item.id, iconName: item.iconName, title: item.title,
                       when: DayText.short(day, calendar: calendar), time: TimeText.range(item.start, item.end),
                       separator: " · ")
        }
    }
}
