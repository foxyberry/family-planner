import Foundation

/// Board A1n: the kid screens look like night from the first evening-routine slot of the day's
/// template until the kid wakes up (the end of the sleep slot that starts at midnight).
public struct NightSpan: Equatable, Sendable {
    public var start: Int
    public var wake: Int

    public init(start: Int, wake: Int) {
        self.start = start
        self.wake = wake
    }

    public func contains(_ minute: Int) -> Bool { minute >= start || minute < wake }
}

/// Turns a kid's routine and schedule items into the slots of one day.
public enum DayPlanner {
    /// Mon–Fri use the weekday template unless the day is a holiday, which uses Sun; Sat and Sun their own.
    public static func dayType(on day: Day, holidays: Set<Day>, calendar: Calendar) -> DayType {
        switch day.weekday(calendar) {
        case .saturday: .saturday
        case .sunday: .sunday
        default: holidays.contains(day) ? .sunday : .weekday
        }
    }

    /// A weekend or a holiday: the home screen's day-off layout (board E3).
    public static func isDayOff(on day: Day, holidays: Set<Day>, calendar: Calendar) -> Bool {
        dayType(on: day, holidays: holidays, calendar: calendar) != .weekday
    }

    /// The kid's template for `day`: the newest one of that day type that starts on or before it.
    public static func template(for kid: Kid.ID, on day: Day, routines: [Routine], holidays: Set<Day>,
                                calendar: Calendar) -> Routine? {
        let type = dayType(on: day, holidays: holidays, calendar: calendar)
        return routines.filter { $0.kid == kid && $0.dayType == type && $0.from <= day }.max { $0.from < $1.from }
    }

    /// The night look's span for a template, or `nil` when it has no evening routine or no
    /// morning sleep (the screens then stay in the day look).
    public static func nightSpan(of routine: Routine?) -> NightSpan? {
        guard let blocks = routine?.blocks,
              let start = blocks.filter({ $0.kind == .evening }).map(\.start).min(),
              let wake = blocks.first(where: { $0.kind == .sleep && $0.start == 0 })?.end
        else { return nil }
        return NightSpan(start: start, wake: wake)
    }

    /// Whether `item` is on `kid`'s day `day`.
    public static func occurs(_ item: ScheduleItem, on day: Day, kid: Kid.ID, holidays: Set<Day>,
                              calendar: Calendar) -> Bool {
        item.audience.includes(kid) && matches(item, on: day, holidays: holidays, calendar: calendar)
    }

    /// Whether `item` falls on `day` for whoever it is for.
    static func matches(_ item: ScheduleItem, on day: Day, holidays: Set<Day>, calendar: Calendar) -> Bool {
        if item.skippedDays.contains(day) { return false }
        // An item after School follows School's days: its "No school days" decides a day off.
        if item.skipsHolidays && item.after != .school && holidays.contains(day) { return false }
        switch item.recurrence {
        case let .once(date):
            return date == day
        case let .weekly(days, from, until):
            return days.contains(day.weekday(calendar)) && day >= from && (until.map { day <= $0 } ?? true)
        }
    }

    /// The day's slots, sorted, never overlapping. When two things share time the higher priority wins
    /// (just once > every week > routine); between equals the later start wins. Lower ones are cut around it.
    public static func slots(on day: Day, kid: Kid, routines: [Routine], items: [ScheduleItem],
                             holidays: Set<Day>, calendar: Calendar) -> [Slot] {
        let routine = template(for: kid.id, on: day, routines: routines, holidays: holidays, calendar: calendar)
        var candidates: [(priority: Int, slot: Slot)] = []
        for block in routine?.blocks ?? [] {
            candidates.append((0, Slot(title: block.title, iconName: block.iconName, kind: block.kind,
                                       start: block.start, end: block.end, source: .routine, showsStar: false,
                                       trip: block.trip)))
        }
        let occurring = items.filter { occurs($0, on: day, kid: kid.id, holidays: holidays, calendar: calendar) }
            .map { $0.on(day) }
        for (item, start) in placed(occurring, schoolEnd: routine?.blocks.first { $0.kind == .school }?.end) {
            let source: Slot.Source = item.isWeekly ? .weekly(item.id) : .once(item.id)
            candidates.append((item.isWeekly ? 1 : 2,
                               Slot(title: item.title, iconName: item.iconName, kind: item.kind, start: start,
                                    end: start + item.end - item.start, source: source,
                                    showsStar: item.showsStar && !item.isWeekly, trip: item.trip,
                                    after: item.after)))
        }
        candidates.sort { ($0.priority, $0.slot.start) > ($1.priority, $1.slot.start) }

        var claimed: [Range<Int>] = []
        var result: [Slot] = []
        for (_, slot) in candidates {
            let start = max(0, slot.start), end = min(1440, slot.end)
            guard start < end else { continue }
            for piece in subtract(claimed, from: start..<end) {
                var part = slot
                part.start = piece.lowerBound
                part.end = piece.upperBound
                result.append(part)
                claimed.append(piece)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    /// The day's items with their start (spec "Events: one shape", From): an item "after" an event
    /// starts its gap after that event ends and keeps its length; if that event is not on the day (a
    /// holiday, skipped, another weekday) the item is left out too, unless it follows School and has
    /// a "No school days" time: then it starts from Home at that time with its own trip. Chains
    /// resolve in order, a few links deep.
    static func placed(_ items: [ScheduleItem], schoolEnd: Int?) -> [(ScheduleItem, Int)] {
        var ends: [EventRef: Int] = [:]
        if let schoolEnd { ends[.school] = schoolEnd }
        var placed: [(ScheduleItem, Int)] = []
        var waiting: [ScheduleItem] = []
        for item in items {
            if item.after == nil {
                placed.append((item, item.start))
                ends[.item(item.id)] = item.end
            } else {
                waiting.append(item)
            }
        }
        // Each pass places the links whose event is placed; four passes cover any real chain.
        for _ in 0..<4 where !waiting.isEmpty {
            waiting = waiting.filter { item in
                guard let after = item.after, let end = ends[after] else { return true }
                let start = end + item.afterGap
                placed.append((item, start))
                ends[.item(item.id)] = start + item.end - item.start
                return false
            }
        }
        if schoolEnd == nil {
            for item in waiting where item.after == .school {
                guard let plan = item.noSchool else { continue }
                var fromHome = item
                fromHome.trip = plan.trip
                fromHome.after = nil
                placed.append((fromHome, plan.start))
                ends[.item(item.id)] = plan.start + item.end - item.start
            }
        }
        return placed
    }

    /// The slot running at `minute` and the one after it (or after the gap `minute` is in).
    public static func now(at minute: Int, in slots: [Slot]) -> (current: Slot?, next: Slot?) {
        let current = slots.first { $0.start <= minute && minute < $0.end }
        let after = current?.end ?? minute
        let next = slots.first { $0.start >= after && $0.start > minute }
        return (current, next)
    }

    /// The parts of `range` not covered by any of `taken`.
    private static func subtract(_ taken: [Range<Int>], from range: Range<Int>) -> [Range<Int>] {
        var pieces = [range]
        for cut in taken {
            pieces = pieces.flatMap { piece -> [Range<Int>] in
                guard piece.overlaps(cut) else { return [piece] }
                var parts: [Range<Int>] = []
                if piece.lowerBound < cut.lowerBound { parts.append(piece.lowerBound..<cut.lowerBound) }
                if cut.upperBound < piece.upperBound { parts.append(cut.upperBound..<piece.upperBound) }
                return parts
            }
        }
        return pieces
    }
}
