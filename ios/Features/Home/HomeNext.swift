import Domain
import Foundation
import KitArt

/// One row in home's next list (spec A1 "Next things", layout v75): one thing for one or more kids.
public struct NextThing: Equatable, Sendable, Identifiable {
    /// The same thing for every kid who does it ("item:{id}" or "slot:{kind}:{title}:{start}:{end}"),
    /// with its day.
    public var id: String
    /// The kids who do it, in family order (their faces under the title).
    public var kids: [Kid.ID]
    public var title: String
    public var iconName: String
    /// When the kids must act, in minutes of its day: the start, or an outing's leave time.
    public var act: Int
    /// 0 today, 1 tomorrow, more for a later day.
    public var inDays: Int
    public var day: Day
    public var weekday: Weekday
    /// The kids for whom this outing has something to check before leaving (their open mission
    /// window leads to it): the row becomes a mission row.
    public var missionKids: [Kid.ID]

    public init(id: String, kids: [Kid.ID], title: String, iconName: String, act: Int, inDays: Int, day: Day,
                weekday: Weekday, missionKids: [Kid.ID] = []) {
        self.id = id
        self.kids = kids
        self.title = title
        self.iconName = iconName
        self.act = act
        self.inDays = inDays
        self.day = day
        self.weekday = weekday
        self.missionKids = missionKids
    }

    public var picture: KitSlot { KitSlot(iconName: iconName) }
    public var isMission: Bool { !missionKids.isEmpty }
}

/// Spec A1 "Next things": what comes next for the whole family, in time order, nearest first.
public enum HomeNext {
    /// One kid's day as the list reads it.
    public struct KidDay: Equatable, Sendable {
        public var kid: Kid.ID
        public var today: [Slot]
        public var tomorrow: [Slot]
        /// The next day with a plan within 14 days, for a kid with nothing left today or tomorrow.
        public var ahead: AheadRow?
        /// Today's outings that have something to check before leaving (their own list).
        public var missionOutings: [Slot]

        public init(kid: Kid.ID, today: [Slot], tomorrow: [Slot], ahead: AheadRow?, missionOutings: [Slot]) {
            self.kid = kid
            self.today = today
            self.tomorrow = tomorrow
            self.ahead = ahead
            self.missionOutings = missionOutings
        }
    }

    /// Every kid's next things from now to the end of the day (free time and a slot that only
    /// resumes after an item are skipped). A kid whose day has nothing left, or who is asleep for the
    /// night, gets the next day's first things instead (tomorrow's after wake-up, else the next day
    /// with a plan within 14 days). The same thing for several kids is one row with all their faces:
    /// the same item, or template slots whose kind, title, start and end all match.
    public static func things(_ days: [KidDay], minute: Int, today: Day, calendar: Calendar) -> [NextThing] {
        var rows: [NextThing] = []
        for day in days {
            for thing in entries(day, minute: minute, today: today, calendar: calendar) {
                if let index = rows.firstIndex(where: { $0.id == thing.id }) {
                    rows[index].kids.append(day.kid)
                    rows[index].missionKids += thing.missionKids
                } else {
                    rows.append(thing)
                }
            }
        }
        let order = Dictionary(days.enumerated().map { ($1.kid, $0) }, uniquingKeysWith: { first, _ in first })
        return rows.sorted { a, b in
            if a.inDays != b.inDays { return a.inDays < b.inDays }
            if a.act != b.act { return a.act < b.act }
            let first = { (thing: NextThing) in thing.kids.first.flatMap { order[$0] } ?? 0 }
            return (first(a), a.title) < (first(b), b.title)
        }
    }

    private static func entries(_ day: KidDay, minute: Int, today: Day, calendar: Calendar) -> [NextThing] {
        let current = DayPlanner.now(at: minute, in: day.today).current
        let asleep = current?.kind == .sleep && minute >= 720
        let left = asleep ? [] : day.today.filter { $0.start > minute && shows($0, in: day.today) }
        if !left.isEmpty {
            return left.map { thing($0, kid: day.kid, inDays: 0, on: today, missions: day.missionOutings, calendar: calendar) }
        }
        let tomorrow = today.adding(days: 1, calendar: calendar)
        let wake = day.tomorrow.first { $0.start == 0 && $0.kind == .sleep }?.end ?? 0
        let first = day.tomorrow.filter { $0.start >= wake && shows($0, in: day.tomorrow) }
        if !first.isEmpty {
            return first.map { thing($0, kid: day.kid, inDays: 1, on: tomorrow, missions: [], calendar: calendar) }
        }
        guard let ahead = day.ahead else { return [] }
        let item = ahead.item
        return [NextThing(id: "slot:\(item.kind.rawValue):\(item.title):\(item.start):\(item.end):\(ahead.inDays)",
                          kids: [day.kid], title: item.title, iconName: item.iconName, act: item.start,
                          inDays: ahead.inDays, day: ahead.day, weekday: ahead.weekday)]
    }

    private static func thing(_ slot: Slot, kid: Kid.ID, inDays: Int, on day: Day, missions: [Slot],
                              calendar: Calendar) -> NextThing {
        let key = switch slot.source {
        case let .weekly(id), let .once(id): "item:\(id):\(slot.start)"
        case .routine: "slot:\(slot.kind.rawValue):\(slot.title):\(slot.start):\(slot.end)"
        }
        let act = slot.trip.map { slot.start - $0.leaveBefore } ?? slot.start
        return NextThing(id: "\(key):\(inDays)", kids: [kid], title: slot.title, iconName: slot.iconName, act: act,
                         inDays: inDays, day: day, weekday: day.weekday(calendar),
                         missionKids: missions.contains(slot) ? [kid] : [])
    }

    /// A slot the list can name: not free time, not a template slot that only resumes after an item.
    static func shows(_ slot: Slot, in slots: [Slot]) -> Bool {
        guard slot.kind != .free else { return false }
        guard slot.source == .routine,
              let item = slots.first(where: { $0.end == slot.start && $0.source != .routine }) else { return true }
        return !slots.contains { $0.source == .routine && $0.title == slot.title && $0.kind == slot.kind && $0.end == item.start }
    }
}
