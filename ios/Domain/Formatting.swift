import Foundation

/// Times as the screens print them (English, fixed format, never the device locale).
public enum TimeText {
    /// "3:30": 12-hour, no am/pm (kid screens and the clock hub).
    public static func clock(_ minute: Int) -> String {
        let hour = (minute / 60) % 12
        return "\(hour == 0 ? 12 : hour):\(String(format: "%02d", minute % 60))"
    }

    /// "3:30 pm" (grown-up screens).
    public static func withPeriod(_ minute: Int) -> String {
        "\(clock(minute)) \((minute / 60) % 24 < 12 ? "am" : "pm")"
    }

    /// "1 hour", "2 hours", "1 hr 30 min", "45 min".
    public static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if rest == 0 { return hours == 1 ? "1 hour" : "\(hours) hours" }
        if hours == 0 { return "\(rest) min" }
        return "\(hours) hr \(rest) min"
    }
}

/// Days as the screens print them.
public enum DayText {
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public static func name(_ weekday: Weekday) -> String { weekdayNames[weekday.rawValue - 1] }
    public static func shortName(_ weekday: Weekday) -> String { String(name(weekday).prefix(3)) }

    /// "9 Nov"
    public static func dayMonth(_ day: Day, calendar: Calendar) -> String { "\(day.day) \(monthNames[day.month - 1])" }
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
        if days == Weekday.schoolDays { return "Every school day" }
        return days.sorted().map(shortName).joined(separator: " · ")
    }

    /// "Monday", "Monday and Wednesday", "Monday, Wednesday and Friday", or "school day".
    public static func sentence(_ days: Set<Weekday>) -> String {
        if days == Weekday.schoolDays { return "school day" }
        let names = days.sorted().map(name)
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }
}
