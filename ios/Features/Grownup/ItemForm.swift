import Domain
import Foundation

/// What a form problem says under its row (board C3, validation).
public enum FormProblem: Equatable, Sendable {
    case noName, endsBeforeStart, noDay, timePassed

    public var message: String {
        switch self {
        case .noName: "Give it a name"
        case .endsBeforeStart: "Ends before it starts"
        case .noDay: "Pick at least one day"
        case .timePassed: "That time has passed"
        }
    }
}

/// The add/edit form's values and its rules (boards C3, C4, E5). Pure, so every rule is tested.
public struct ItemForm: Equatable, Sendable {
    public enum Repeat: Equatable, Sendable { case once, weekly }

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

    /// Board C3 defaults: the next full hour for an hour, every week on today's weekday, holidays skipped.
    public static func defaults(audience: Audience, now: Date, calendar: Calendar) -> ItemForm {
        let today = Day(now, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let nextHour = min(((parts.hour ?? 0) + 1) * 60, 1380)
        return ItemForm(audience: audience, iconName: nil, name: "", start: nextHour, end: nextHour + 60,
                        repeats: .weekly, days: [today.weekday(calendar)], date: today, skipsHolidays: true,
                        showsStar: true)
    }

    public init(audience: Audience, iconName: String?, name: String, start: Int, end: Int, repeats: Repeat,
                days: Set<Weekday>, date: Day, skipsHolidays: Bool, showsStar: Bool) {
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
    }

    /// The form for editing `item`.
    public init(item: ScheduleItem) {
        switch item.recurrence {
        case let .once(day):
            self.init(audience: item.audience, iconName: item.iconName, name: item.title, start: item.start,
                      end: item.end, repeats: .once, days: [], date: day, skipsHolidays: true,
                      showsStar: item.showsStar)
        case let .weekly(days, from, _):
            self.init(audience: item.audience, iconName: item.iconName, name: item.title, start: item.start,
                      end: item.end, repeats: .weekly, days: days, date: from, skipsHolidays: item.skipsHolidays,
                      showsStar: true)
        }
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
    public func problem(today: Day, nowMinute: Int) -> FormProblem? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return .noName }
        if end <= start { return .endsBeforeStart }
        if repeats == .weekly && days.isEmpty { return .noDay }
        if repeats == .once && date == today && start < nowMinute { return .timePassed }
        return nil
    }

    /// "1 hour", "1 hr 30 min", or nothing while the times are the wrong way round.
    public var durationCaption: String? { end > start ? TimeText.duration(end - start) : nil }

    /// A note under "When" if another item for the same kid shares this time (not blocking).
    public func overlapCaption(items: [ScheduleItem], kids: [Kid], holidays: Set<Day>, editing: ScheduleItem.ID?,
                               calendar: Calendar) -> String? {
        let mine = kids.filter { audience.includes($0.id) }.map(\.id)
        for other in items where other.id != editing && other.start < end && start < other.end {
            let shared = mine.filter { other.audience.includes($0) }
            guard let kid = shared.first, sharesDay(with: other, kid: kid, holidays: holidays, calendar: calendar)
            else { continue }
            let myPriority = repeats == .once ? 2 : 1
            let otherPriority = other.isWeekly ? 1 : 2
            let mineWins = myPriority > otherPriority || (myPriority == otherPriority && start >= other.start)
            return mineWins
                ? "Overlaps \(other.title) \(TimeText.clock(other.start))–\(TimeText.clock(other.end)). This one shows on the clock then."
                : "\(other.title) shows on the clock then."
        }
        return nil
    }

    private func sharesDay(with other: ScheduleItem, kid: Kid.ID, holidays: Set<Day>, calendar: Calendar) -> Bool {
        switch (repeats, other.recurrence) {
        case (.once, _):
            return DayPlanner.occurs(other, on: date, kid: kid, holidays: holidays, calendar: calendar)
        case let (.weekly, .weekly(otherDays, _, _)):
            return !days.isDisjoint(with: otherDays)
        case let (.weekly, .once(day)):
            return days.contains(day.weekday(calendar))
        }
    }

    /// "On the clock every Monday and Wednesday from 9 Nov." (every-week items only).
    public func summaryCaption(today: Day, calendar: Calendar) -> String? {
        guard repeats == .weekly, !days.isEmpty else { return nil }
        return "On the clock every \(DayText.sentence(days)) from \(DayText.dayMonth(today, calendar: calendar))."
    }

    /// The item to save. A new every-week item starts today.
    public func item(id: UUID, today: Day) -> ScheduleItem {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch repeats {
        case .weekly:
            return ScheduleItem(id: id, title: trimmed, iconName: iconName ?? "actPlay", audience: audience, start: start,
                                end: end, recurrence: .weekly(days, from: today, until: nil), skippedDays: [],
                                skipsHolidays: skipsHolidays, showsStar: false)
        case .once:
            return ScheduleItem(id: id, title: trimmed, iconName: iconName ?? "actPlay", audience: audience, start: start,
                                end: end, recurrence: .once(date), skippedDays: [], skipsHolidays: false,
                                showsStar: showsStar)
        }
    }
}
