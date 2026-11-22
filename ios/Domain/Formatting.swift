import Foundation
import Strings

/// Times as the screens print them (English, fixed format, never the device locale).
public enum TimeText {
    /// "3:30": 12-hour without am/pm. Never shown alone on a screen: use `withPeriod` or `range`.
    public static func clock(_ minute: Int) -> String {
        let hour = (minute / 60) % 12
        return "\(hour == 0 ? 12 : hour):\(String(format: "%02d", minute % 60))"
    }

    /// "3:30 pm": every time shown on a screen, kid or grown-up. 1440 is "12:00 am".
    public static func withPeriod(_ minute: Int) -> String {
        "\(clock(minute)) \(period(minute))"
    }

    /// "3:30–4:30 pm" within one half of the day, "7:30 am–3:00 pm" across noon or midnight.
    /// School hours as the boards write them (G6 Settings, S4): "8:00 am – 3:00 pm", both periods, spaced.
    public static func hours(_ start: Int, _ end: Int) -> String {
        "\(withPeriod(start)) – \(withPeriod(end))"
    }

    public static func range(_ start: Int, _ end: Int) -> String {
        start / 720 == end / 720
            ? "\(clock(start))–\(withPeriod(end))"
            : "\(withPeriod(start))–\(withPeriod(end))"
    }

    private static func period(_ minute: Int) -> String {
        (minute / 60) % 24 < 12 ? L10n.tr("time.am") : L10n.tr("time.pm")
    }

    /// "1 hour", "2 hours", "1 hr 30 min", "45 min".
    public static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if rest == 0 { return hours == 1 ? L10n.tr("duration.hour") : L10n.tr("duration.hours", hours) }
        if hours == 0 { return L10n.tr("duration.min", rest) }
        return L10n.tr("duration.hr_min", hours, rest)
    }
}

/// Days as the screens print them.
public enum DayText {
    public static func name(_ weekday: Weekday) -> String {
        switch weekday {
        case .sunday: L10n.tr("weekday.sunday")
        case .monday: L10n.tr("weekday.monday")
        case .tuesday: L10n.tr("weekday.tuesday")
        case .wednesday: L10n.tr("weekday.wednesday")
        case .thursday: L10n.tr("weekday.thursday")
        case .friday: L10n.tr("weekday.friday")
        case .saturday: L10n.tr("weekday.saturday")
        }
    }

    /// "Mon"
    public static func shortName(_ weekday: Weekday) -> String {
        switch weekday {
        case .sunday: L10n.tr("weekday.short.sunday")
        case .monday: L10n.tr("weekday.short.monday")
        case .tuesday: L10n.tr("weekday.short.tuesday")
        case .wednesday: L10n.tr("weekday.short.wednesday")
        case .thursday: L10n.tr("weekday.short.thursday")
        case .friday: L10n.tr("weekday.short.friday")
        case .saturday: L10n.tr("weekday.short.saturday")
        }
    }


    /// Monday … Sunday, the order the calendar's columns read.
    public static let mondayFirst: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    /// "M": the letter on a day chip.
    public static func initial(_ weekday: Weekday) -> String { String(name(weekday).prefix(1)) }

    /// "9 Nov"
    public static func dayMonth(_ day: Day, calendar: Calendar) -> String { "\(day.day) \(monthName(day.month))" }

    /// Board G2m: "2nd Sat" or "14th", for "Every 2nd Sat" / "Every 14th".
    public static func monthlyEvery(_ rule: MonthlyRule) -> String {
        switch rule {
        case .nthWeekday: L10n.tr("monthly.every", monthly(rule))
        case let .dayOfMonth(date): L10n.tr("monthly.every", ordinal(date))
        }
    }

    /// "1st", "2nd", "3rd", "4th" … "11th", "12th", "13th", "21st", "22nd", "31st".
    public static func ordinal(_ number: Int) -> String {
        let teen = (11...13).contains(number % 100)
        switch number % 10 {
        case 1 where !teen: return L10n.tr("ordinal.st", number)
        case 2 where !teen: return L10n.tr("ordinal.nd", number)
        case 3 where !teen: return L10n.tr("ordinal.rd", number)
        default: return L10n.tr("ordinal.th", number)
        }
    }

    /// Board C3m: "2nd Sat" or "Day 14".
    public static func monthly(_ rule: MonthlyRule) -> String {
        switch rule {
        case let .nthWeekday(nth, weekday):
            switch nth {
            case ...1: L10n.tr("monthly.nth.1", shortName(weekday))
            case 2: L10n.tr("monthly.nth.2", shortName(weekday))
            case 3: L10n.tr("monthly.nth.3", shortName(weekday))
            case 4: L10n.tr("monthly.nth.4", shortName(weekday))
            default: L10n.tr("monthly.nth.5", shortName(weekday))
            }
        case let .dayOfMonth(date): L10n.tr("monthly.day", date)
        }
    }
    /// "Sat 14 Nov"
    /// "Tue 1 Dec", when the weekday is known already.
    public static func short(_ day: Day, weekday: Weekday) -> String {
        "\(shortName(weekday)) \(day.day) \(monthName(day.month))"
    }

    public static func short(_ day: Day, calendar: Calendar) -> String {
        "\(shortName(day.weekday(calendar))) \(dayMonth(day, calendar: calendar))"
    }
    /// "Saturday 14 Nov"
    public static func long(_ day: Day, calendar: Calendar) -> String {
        "\(name(day.weekday(calendar))) \(dayMonth(day, calendar: calendar))"
    }

    /// "Mon · Wed", or "Every school day" for Monday to Friday.
    public static func chips(_ days: Set<Weekday>) -> String {
        if days == Weekday.schoolDays { return L10n.tr("days.every_school_day") }
        return days.sorted().map(shortName).joined(separator: " · ")
    }

    /// "Monday", "Monday and Wednesday", "Monday, Wednesday and Friday", or "school day".
    public static func sentence(_ days: Set<Weekday>) -> String {
        if days == Weekday.schoolDays { return L10n.tr("days.school_day") }
        return list(days.sorted().map(name))
    }

    /// "Every Mon", "Every Mon and Wed", "Every Mon, Wed and Fri", or "Every school day".
    public static func every(_ days: Set<Weekday>) -> String {
        if days == Weekday.schoolDays { return L10n.tr("days.every_school_day") }
        return L10n.tr("days.every", list(days.sorted().map(shortName)))
    }

    /// "A", "A and B", "A, B and C".
    public static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return L10n.tr("list.and", names.dropLast().joined(separator: ", "), last)
    }

    /// "November", for a month heading (board G1c).
    public static func monthLong(_ month: Int) -> String {
        switch month {
        case 1: L10n.tr("month.long.jan")
        case 2: L10n.tr("month.long.feb")
        case 3: L10n.tr("month.long.mar")
        case 4: L10n.tr("month.long.apr")
        case 5: L10n.tr("month.long.may")
        case 6: L10n.tr("month.long.jun")
        case 7: L10n.tr("month.long.jul")
        case 8: L10n.tr("month.long.aug")
        case 9: L10n.tr("month.long.sep")
        case 10: L10n.tr("month.long.oct")
        case 11: L10n.tr("month.long.nov")
        default: L10n.tr("month.long.dec")
        }
    }

    private static func monthName(_ month: Int) -> String {
        switch month {
        case 1: L10n.tr("month.jan")
        case 2: L10n.tr("month.feb")
        case 3: L10n.tr("month.mar")
        case 4: L10n.tr("month.apr")
        case 5: L10n.tr("month.may")
        case 6: L10n.tr("month.jun")
        case 7: L10n.tr("month.jul")
        case 8: L10n.tr("month.aug")
        case 9: L10n.tr("month.sep")
        case 10: L10n.tr("month.oct")
        case 11: L10n.tr("month.nov")
        default: L10n.tr("month.dec")
        }
    }
}

/// The bus league's words (spec "Leagues").
public enum LeagueText {
    /// "12 more Go! days to the Double-Decker"; "Next stop: …" once the goal is reached.
    public static func remaining(done: Int, goal: Int, nextName: String) -> String {
        let left = max(goal - done, 0)
        guard left > 0 else { return L10n.tr("league.next_stop", nextName) }
        return left == 1 ? L10n.tr("league.left.one", left, nextName) : L10n.tr("league.left.other", left, nextName)
    }
}

/// Minutes left as the kid screens print and speak them.
public enum TimeLeftText {
    /// "19 min"; at zero or below the true minus sign (U+2212), "−2 min". Over an hour: "1h 20m"
    /// (or "2h").
    public static func short(minutes: Int) -> String {
        if minutes > 60 {
            let hours = minutes / 60, rest = minutes % 60
            return rest == 0 ? L10n.tr("time_left.h", "\(hours)") : L10n.tr("time_left.h_min", "\(hours)", "\(rest)")
        }
        let number = minutes < 0 ? "\u{2212}\(-minutes)" : "\(minutes)"
        return L10n.tr("time_left.min", number)
    }

    /// Late red at zero or below.
    public static func isLate(minutes: Int) -> Bool { minutes <= 0 }
}
