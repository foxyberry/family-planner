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


    /// "M": the letter on a day chip.
    public static func initial(_ weekday: Weekday) -> String { String(name(weekday).prefix(1)) }

    /// "9 Nov"
    public static func dayMonth(_ day: Day, calendar: Calendar) -> String { "\(day.day) \(monthName(day.month))" }
    /// "Sat 14 Nov"
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
    private static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return L10n.tr("list.and", names.dropLast().joined(separator: ", "), last)
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
