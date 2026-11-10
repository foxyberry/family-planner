import Domain
import Foundation
import Strings

/// What a form problem says under its row (board C3, validation).
public enum FormProblem: Equatable, Sendable {
    case noName, endsBeforeStart, noDay, timePassed

    public var message: String {
        switch self {
        case .noName: L10n.tr("form.problem.no_name")
        case .endsBeforeStart: L10n.tr("form.problem.ends_before_start")
        case .noDay: L10n.tr("form.problem.no_day")
        case .timePassed: L10n.tr("form.problem.time_passed")
        }
    }

    /// The form row this problem shows under.
    public var row: FormRow {
        switch self {
        case .noName: .name
        case .endsBeforeStart, .timePassed: .when
        case .noDay: .days
        }
    }
}

/// The form rows that can show a problem.
public enum FormRow: Equatable, Sendable { case name, when, days }

/// The add/edit form's values and its rules (boards C3, C4, E5). Pure, so every rule is tested.
public struct ItemForm: Equatable, Sendable {
    public enum Repeat: Hashable, Sendable { case once, weekly }

    public var audience: Audience
    public var iconName: String?
    public var name: String
    public var start: Int
    public var end: Int
    public var repeats: Repeat
    public var days: Set<Weekday>
    public var date: Day
    public var skipsHolidays: Bool
    public var showsStar: Bool
    /// "Going" (board C3g): how the kid goes and how long before the start they leave; nil = None.
    public var trip: Trip?
    /// "From" (spec "Event form rows"): nil is Home; an event makes the item start when it ends.
    public var after: EventRef?
    /// "Bring" and "Missions" (before / after), up to `ItemMission.most` each.
    public var bring: [ItemMission] = []
    public var missionsBefore: [ItemMission] = []
    public var missionsAfter: [ItemMission] = []
    /// Runs (board G2): how an every-week item's run ends; `date` is its start.
    public var runsEnd: RunsEndKind = .none
    public var untilDate: Day
    public var times = 10

    /// "School end + 15 min" (0–60, step 5) for an item that follows an event.
    public var afterGap = 0
    /// No school days (an item after School): nil skips the day; a time keeps it, from Home.
    public var noSchoolStart: Int?
    public var noSchoolWay: Domain.Way?

    /// The end choices in the Runs card.
    public enum RunsEndKind: Hashable, Sendable { case term, date, count, none }

    public static let defaultLeave = 10

    /// Board C3 defaults: the next full hour for an hour, every week on today's weekday, holidays skipped.
    public static func defaults(audience: Audience, now: Date, calendar: Calendar) -> ItemForm {
        let today = Day(now, calendar: calendar)
        let nextHour = min((Day.minute(of: now, calendar: calendar) / 60 + 1) * 60, 1380)
        // Spec "Repeats, dates and changes": Skip school holidays is off for an activity (on when it
        // follows School).
        return ItemForm(audience: audience, iconName: nil, name: "", start: nextHour, end: nextHour + 60,
                        repeats: .weekly, days: [today.weekday(calendar)], date: today, skipsHolidays: false,
                        showsStar: true)
    }

    public init(audience: Audience, iconName: String?, name: String, start: Int, end: Int, repeats: Repeat,
                days: Set<Weekday>, date: Day, skipsHolidays: Bool, showsStar: Bool, trip: Trip? = nil) {
        self.trip = trip
        self.audience = audience
        self.iconName = iconName
        self.name = name
        self.start = start
        self.end = end
        self.repeats = repeats
        self.days = days
        self.date = date
        self.skipsHolidays = skipsHolidays
        self.showsStar = showsStar
        untilDate = date
    }

    /// The form for editing `item`.
    public init(item: ScheduleItem) {
        switch item.recurrence {
        case let .once(day):
            self.init(audience: item.audience, iconName: item.iconName, name: item.title, start: item.start,
                      end: item.end, repeats: .once, days: [], date: day, skipsHolidays: true,
                      showsStar: item.showsStar, trip: item.trip)
        case let .weekly(days, from, _):
            self.init(audience: item.audience, iconName: item.iconName, name: item.title, start: item.start,
                      end: item.end, repeats: .weekly, days: days, date: from, skipsHolidays: item.skipsHolidays,
                      showsStar: true, trip: item.trip)
        }
        after = item.after
        afterGap = item.afterGap
        noSchoolStart = item.noSchool?.start
        noSchoolWay = item.noSchool?.trip?.way
        if case let .weekly(_, _, until) = item.recurrence {
            switch item.runsEnd {
            case .term?: runsEnd = .term
            case let .count(n)?: runsEnd = .count; times = n
            case .date?: runsEnd = .date
            case .none?, nil: runsEnd = until == nil ? .none : .date
            }
            if let until { untilDate = until }
        }
        bring = item.bring
        missionsBefore = item.missionsBefore
        missionsAfter = item.missionsAfter
    }

    /// Picking a picture fills an empty name with the picture's label; a typed name is never replaced.
    public mutating func pickPicture(_ name: String) {
        iconName = name
        if self.name.trimmingCharacters(in: .whitespaces).isEmpty { self.name = Self.label(for: name) }
    }

    /// "actSwim" → "Swim", "busDouble" → "Bus double".
    static func label(for iconName: String) -> String {
        var raw = Substring(iconName)
        if raw.hasPrefix("act"), raw.dropFirst(3).first?.isUppercase == true { raw = raw.dropFirst(3) }
        if raw.allSatisfy(\.isUppercase) { return String(raw) }
        var words: [String] = []
        for character in raw {
            if character.isUppercase || words.isEmpty { words.append(String(character)) } else {
                words[words.count - 1].append(character)
            }
        }
        let sentence = words.joined(separator: " ").lowercased()
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    /// The first problem, in the order the rows read.
    /// `keptStart`: when editing, the saved start time, which may already have passed.
    public func problem(today: Day, nowMinute: Int, keptStart: Int? = nil) -> FormProblem? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return .noName }
        if end <= start { return .endsBeforeStart }
        if repeats == .weekly && days.isEmpty { return .noDay }
        if repeats == .once && date == today && start < nowMinute && start != keptStart { return .timePassed }
        return nil
    }

    /// Picks how the kid goes; the leave minutes, the way home and the medal stay when the way
    /// changes (default leave 10).
    public mutating func setGoing(_ way: Domain.Way?) {
        trip = way.map {
            Trip(way: $0, leaveBefore: trip?.leaveBefore ?? Self.defaultLeave, homeAfter: trip?.homeAfter ?? 0,
                 medal: trip?.medal, lateGrace: trip?.lateGrace)
        }
    }

    /// −/+ on the Leave row: 0–90 in steps of 5.
    public mutating func stepLeave(_ step: Int) {
        guard var trip else { return }
        trip.leaveBefore = min(max(trip.leaveBefore + 5 * step, 0), 90)
        self.trip = trip
    }

    // MARK: Event form rows (spec "Event form rows for 6b", board G2b)

    /// One choice in the From card: Home (`event` nil) or an event this item can follow.
    public struct FromChoice: Equatable, Sendable {
        public var event: EventRef?
        public var title: String
        /// A `KitSlot` raw value.
        public var picture: String
        /// When the event ends (the linked start); 0 for Home.
        public var end: Int
    }

    /// Picks From: "After {event}" starts the item at the event's end, keeps its length and drops
    /// the trip (same place); Home keeps the times and shows Going again.
    public mutating func setFrom(_ choice: FromChoice) {
        after = choice.event
        guard choice.event != nil else { return }
        // An item after School follows School's days, holidays included.
        if choice.event == .school { skipsHolidays = true }
        let length = max(end - start, 5)
        start = min(choice.end + afterGap, 1435)
        end = min(start + length, 1440)
        trip = nil
    }

    /// −/+ for the minutes after the event (0–60, step 5); a linked item's times move with it.
    public mutating func stepGap(_ step: Int) {
        let gap = min(max(afterGap + 5 * step, 0), 60)
        guard after != nil else { afterGap = gap; return }
        let length = end - start
        start = min(max(start + gap - afterGap, 0), 1435)
        end = min(start + length, 1440)
        afterGap = gap
    }

    /// No school days: Skip, or at a set time (the item's own start by default).
    public mutating func setNoSchool(atSetTime: Bool) {
        noSchoolStart = atSetTime ? (noSchoolStart ?? start) : nil
        if !atSetTime { noSchoolWay = nil }
    }

    var noSchool: NoSchoolPlan? {
        guard after == .school, let noSchoolStart else { return nil }
        return NoSchoolPlan(start: noSchoolStart,
                            trip: noSchoolWay.map { Trip(way: $0, leaveBefore: trip?.leaveBefore ?? Self.defaultLeave) })
    }

    /// The Medal switch: on only with a trip; nil means the default (off for an item).
    public var medalIsOn: Bool { trip?.givesMedal(isSchool: false) ?? false }
    public var canSwitchMedal: Bool { trip != nil }

    public mutating func toggleMedal() {
        guard var trip else { return }
        trip.medal = !medalIsOn
        self.trip = trip
    }

    /// Bring: a tap adds the picture (named after it) or takes it away; four at most.
    public mutating func toggleBring(_ picture: String, id: UUID) {
        if let index = bring.firstIndex(where: { $0.picture == picture }) {
            bring.remove(at: index)
        } else if bring.count < ItemMission.most {
            bring.append(ItemMission(id: id, name: Self.label(for: picture), picture: picture))
        }
    }

    /// The missions before leaving for the item, or after coming home from it.
    public enum MissionSection: Hashable, Sendable { case before, after }

    public func missions(_ section: MissionSection) -> [ItemMission] {
        section == .before ? missionsBefore : missionsAfter
    }

    /// Adds a mission (up to four) or replaces the one with the same id.
    public mutating func saveMission(_ mission: ItemMission, in section: MissionSection) {
        var list = missions(section)
        if let index = list.firstIndex(where: { $0.id == mission.id }) {
            list[index] = mission
        } else if list.count < ItemMission.most {
            list.append(mission)
        }
        setMissions(list, section)
    }

    public mutating func removeMission(_ id: ItemMission.ID) {
        missionsBefore.removeAll { $0.id == id }
        missionsAfter.removeAll { $0.id == id }
    }

    /// Drag ≡: moves a mission to `index` within its section.
    public mutating func moveMission(_ id: ItemMission.ID, to index: Int, in section: MissionSection) {
        var list = missions(section)
        guard let from = list.firstIndex(where: { $0.id == id }) else { return }
        let mission = list.remove(at: from)
        list.insert(mission, at: min(max(index, 0), list.count))
        setMissions(list, section)
    }

    private mutating func setMissions(_ list: [ItemMission], _ section: MissionSection) {
        if section == .before { missionsBefore = list } else { missionsAfter = list }
    }

    // MARK: Runs (board G2)

    /// The stored `until`: the picked date; term and count ends are worked out with the calendar.
    var until: Day? { runsEnd == .date ? max(untilDate, date) : nil }

    var storedRunsEnd: RunsEnd {
        switch runsEnd {
        case .term: .term
        case .date: .date
        case .count: .count(times)
        case .none: .none
        }
    }

    /// "9 Nov", the Runs start field.
    public func runsStartText(calendar: Calendar) -> String { DayText.dayMonth(date, calendar: calendar) }

    /// The Runs end field: "End of term", "20 Nov", "After 8 times" or "No end".
    public func runsEndText(calendar: Calendar) -> String {
        switch runsEnd {
        case .term: L10n.tr("runs.end.term")
        case .date: DayText.dayMonth(max(untilDate, date), calendar: calendar)
        case .count: L10n.tr("runs.end.count", times)
        case .none: L10n.tr("runs.end.none")
        }
    }

    /// −/+ in the Runs card: 1–40 times.
    public mutating func stepTimes(_ step: Int) { times = min(max(times + step, 1), 40) }

    /// The Bring row's words: "Swimsuit · Goggles"; nil when nothing is picked.
    public var bringText: String? { bring.isEmpty ? nil : bring.map(\.name).joined(separator: " · ") }

    /// The Missions row's words: the before ones, then the after ones with "(after)".
    public var missionsText: String? {
        let words = missionsBefore.map(\.name) + missionsAfter.map { L10n.tr("missions.row.after", $0.name) }
        return words.isEmpty ? nil : words.joined(separator: " · ")
    }

    /// The From card's choices: Home, then the kid's events that end at or before this item's start
    /// on every one of its days (School first, then by end time); five at most.
    public func fromChoices(kids: [Kid], routines: [Routine], items: [ScheduleItem], editing: ScheduleItem.ID?,
                            today: Day, calendar: Calendar) -> [FromChoice] {
        let home = FromChoice(event: nil, title: L10n.tr("from.home"), picture: "home", end: 0)
        let onDays: Set<Weekday> = repeats == .weekly ? days : [date.weekday(calendar)]
        guard !onDays.isEmpty else { return [home] }
        var events: [FromChoice] = []
        if case let .kid(kid) = audience, onDays.isSubset(of: Weekday.schoolDays),
           let school = routines.filter({ $0.kid == kid && $0.dayType == .weekday && $0.from <= today })
               .max(by: { $0.from < $1.from })?.blocks.first(where: { $0.kind == .school }),
           school.end <= start || after == .school {
            events.append(FromChoice(event: .school, title: school.title, picture: school.iconName, end: school.end))
        }
        let ends = Self.placedEnds(items, schoolEnd: events.first?.end)
        for item in items where item.id != editing && Self.shares(item.audience, with: audience) {
            guard let itemEnd = ends[item.id], itemEnd <= start || after == .item(item.id),
                  covers(item, onDays: onDays, today: today) else { continue }
            events.append(FromChoice(event: .item(item.id), title: item.title, picture: item.iconName, end: itemEnd))
        }
        let school = events.filter { $0.event == .school }
        let rest = events.filter { $0.event != .school }.sorted { $0.end < $1.end }
        return Array(([home] + school + rest).prefix(5))
    }

    /// Whether `item` happens on every one of this form's days.
    private func covers(_ item: ScheduleItem, onDays: Set<Weekday>, today: Day) -> Bool {
        switch (repeats, item.recurrence) {
        case let (.weekly, .weekly(itemDays, _, until)):
            return onDays.isSubset(of: itemDays) && (until.map { $0 >= today } ?? true)
        case let (.once, .weekly(itemDays, from, until)):
            return onDays.isSubset(of: itemDays) && from <= date && (until.map { $0 >= date } ?? true)
        case let (.once, .once(day)):
            return day == date
        case (.weekly, .once):
            return false
        }
    }

    /// A kid's item can follow another of the same kid's; a "Both" item only a "Both" one.
    private static func shares(_ other: Audience, with audience: Audience) -> Bool {
        switch audience {
        case let .kid(kid): other.includes(kid)
        case .both: other == .both
        }
    }

    /// Each item's end, following links ("After …") a few deep from School's end.
    private static func placedEnds(_ items: [ScheduleItem], schoolEnd: Int?) -> [ScheduleItem.ID: Int] {
        var ends: [EventRef: Int] = [:]
        if let schoolEnd { ends[.school] = schoolEnd }
        var result: [ScheduleItem.ID: Int] = [:]
        for _ in 0..<5 {
            for item in items where result[item.id] == nil {
                if let after = item.after {
                    guard let start = ends[after] else { continue }
                    result[item.id] = start + item.end - item.start
                } else {
                    result[item.id] = item.end
                }
                ends[.item(item.id)] = result[item.id]
            }
        }
        return result
    }

    /// "10 min" on the Leave row.
    public var leaveText: String? { trip.map { L10n.tr("going.leave.minutes", $0.leaveBefore) } }

    /// "before · 4:20 pm" after the Leave row's minutes.
    public var leaveCaption: String? {
        trip.map { L10n.tr("going.leave.before", TimeText.withPeriod(max(start - $0.leaveBefore, 0))) }
    }

    /// The preview's line: "Leave 4:20 pm by car." (none without a trip).
    public var leaveLine: String? {
        guard let trip else { return nil }
        return L10n.tr("going.preview", TimeText.withPeriod(max(start - trip.leaveBefore, 0)),
                       Self.wayWord(trip.way))
    }

    static func wayWord(_ way: Domain.Way) -> String {
        switch way {
        case .walk: L10n.tr("way.on_foot")
        case .bus: L10n.tr("way.by_bus")
        case .car: L10n.tr("way.by_car")
        case .taxi: L10n.tr("way.by_taxi")
        case .shuttle: L10n.tr("way.by_shuttle")
        }
    }

    /// "1 hour", "1 hr 30 min", or nothing while the times are the wrong way round.
    public var durationCaption: String? { end > start ? TimeText.duration(end - start) : nil }

    /// A note under "When" if another item for the same kid shares this time (not blocking).
    /// Only items still ahead count: a stopped series or a past event says nothing.
    public func overlapCaption(items: [ScheduleItem], kids: [Kid], family: FamilyCalendar, editing: ScheduleItem.ID?,
                               today: Day? = nil, calendar: Calendar) -> String? {
        let mine = kids.filter { audience.includes($0.id) }.map(\.id)
        let from = max(date, today ?? date)
        for other in items where other.id != editing && other.start < end && start < other.end {
            let shared = mine.filter { other.audience.includes($0) }
            guard let kid = shared.first,
                  sharesDay(with: other, kid: kid, from: from, holidays: family.daysOff(kid), calendar: calendar)
            else { continue }
            let myPriority = repeats == .once ? 2 : 1
            let otherPriority = other.isWeekly ? 1 : 2
            let mineWins = myPriority > otherPriority || (myPriority == otherPriority && start >= other.start)
            return mineWins
                ? L10n.tr("form.overlap.mine", other.title, TimeText.range(other.start, other.end))
                : L10n.tr("form.overlap.other", other.title)
        }
        return nil
    }

    private func sharesDay(with other: ScheduleItem, kid: Kid.ID, from: Day, holidays: Set<Day>,
                           calendar: Calendar) -> Bool {
        switch (repeats, other.recurrence) {
        case (.once, _):
            return DayPlanner.occurs(other, on: date, kid: kid, holidays: holidays, calendar: calendar)
        case let (.weekly, .weekly(otherDays, _, until)):
            return !days.isDisjoint(with: otherDays) && (until.map { $0 >= from } ?? true)
        case let (.weekly, .once(day)):
            return day >= from && days.contains(day.weekday(calendar))
        }
    }

    /// "On the clock every Monday and Wednesday from 9 Nov." (every-week items only).
    public func summaryCaption(today: Day, calendar: Calendar) -> String? {
        guard repeats == .weekly, !days.isEmpty else { return nil }
        return L10n.tr("form.summary", DayText.sentence(days), DayText.dayMonth(today, calendar: calendar))
    }

    /// The item to save. A new every-week item starts today.
    public func item(id: UUID, today: Day) -> ScheduleItem {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch repeats {
        case .weekly:
            return ScheduleItem(id: id, title: trimmed, iconName: iconName ?? "actPlay", audience: audience, start: start,
                                end: end, recurrence: .weekly(days, from: max(date, today), until: until), skippedDays: [],
                                skipsHolidays: skipsHolidays, showsStar: false, trip: trip, after: after,
                                bring: bring, missionsBefore: missionsBefore, missionsAfter: missionsAfter,
                                runsEnd: storedRunsEnd, afterGap: after == nil ? 0 : afterGap, noSchool: noSchool)
        case .once:
            return ScheduleItem(id: id, title: trimmed, iconName: iconName ?? "actPlay", audience: audience, start: start,
                                end: end, recurrence: .once(date), skippedDays: [], skipsHolidays: false,
                                showsStar: showsStar, trip: trip, after: after,
                                bring: bring, missionsBefore: missionsBefore, missionsAfter: missionsAfter,
                                afterGap: after == nil ? 0 : afterGap)
        }
    }

    /// Board C3 "What" row (layout v6): `count` pictures, the picked one first, then the ones used
    /// most (ties keep the kit's order), then the rest of the kit's list. Never repeats a picture.
    public static func rowPictures(picked: String?, used: [String], all: [String], count: Int = 5) -> [String] {
        var row: [String] = []
        func add(_ name: String) { if !row.contains(name), row.count < count { row.append(name) } }
        if let picked { add(picked) }
        let counts = Dictionary(used.map { ($0, 1) }, uniquingKeysWith: +)
        let order = Dictionary(all.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let byUse = counts.keys.filter { order[$0] != nil }.sorted {
            counts[$0, default: 0] != counts[$1, default: 0] ? counts[$0, default: 0] > counts[$1, default: 0]
                : order[$0, default: 0] < order[$1, default: 0]
        }
        byUse.forEach(add)
        all.forEach(add)
        return row
    }
}
