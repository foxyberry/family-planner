import Foundation

/// One stretch of a kid's day when missions show (spec "Events: one shape", Mission windows), with the
/// windows whose missions it lists in order: the morning routine, then the next outing's Bring checks.
public struct WindowSpan: Equatable, Sendable {
    public var start: Int
    public var end: Int
    public var parts: [MissionWindow]
    /// The outing this stretch leads to (its leave ends the stretch), if any.
    public var outing: Outing?
    /// The events linked after that outing ("After {event}"): their Bring is checked before its leave.
    public var linked: [EventRef]

    public init(start: Int, end: Int, parts: [MissionWindow], outing: Outing? = nil, linked: [EventRef] = []) {
        self.start = start
        self.end = end
        self.parts = parts
        self.outing = outing
        self.linked = linked
    }

    public func contains(_ minute: Int) -> Bool { start <= minute && minute < end }
}

public extension DayPlanner {
    /// The morning ends at 12:00 pm when nothing leaves before then.
    static let morningEnd = 720

    /// The day's mission stretches, from the day's points (wake, each outing's leave and home, dinner
    /// and bed). Without a wake-up (no morning sleep in the template) there are none.
    static func missionWindows(slots: [Slot], night: NightSpan?) -> [WindowSpan] {
        guard let wake = night?.wake else { return [] }
        let sorted = slots.sorted { $0.start < $1.start }
        let outings = sorted.filter { $0.start > wake }.compactMap { slot in slot.trip.map { Outing(slot: slot, trip: $0) } }
        let dinner = sorted.first { $0.kind == .dinner && $0.start >= wake }?.start
        let bed = sorted.last { $0.kind == .sleep && $0.end == 1440 && $0.start > wake }?.start ?? night?.start ?? 1440
        let evening = dinner ?? bed

        var spans: [WindowSpan] = []
        func add(_ start: Int, _ end: Int, _ parts: [MissionWindow], _ outing: Outing? = nil) {
            guard start < end, !parts.isEmpty else { return }
            let linked = outing.map { Self.chain(from: $0.slot, in: sorted).dropFirst().compactMap(EventRef.init) } ?? []
            spans.append(WindowSpan(start: start, end: end, parts: parts, outing: outing, linked: Array(linked)))
        }

        // Morning: wake → the first leave, or noon. A leave before noon brings its Bring checks in.
        let noon = min(Self.morningEnd, evening)
        if let first = outings.first, first.leave <= Self.morningEnd {
            add(wake, first.leave, [.morning] + before(first), first)
        } else {
            add(wake, noon, [.morning])
            // The first outing leaves after noon: its "before" stretch runs from noon to its leave.
            if let first = outings.first { add(noon, first.leave, before(first), first) }
        }
        // After each outing: home → the next leave, with that outing's Bring checks. An outing that
        // leaves after dinner has no stretch of its own.
        for (index, outing) in outings.enumerated() {
            guard outings.indices.contains(index + 1) else { break }
            let next = outings[index + 1]
            let chain = Self.chain(from: outing.slot, in: sorted)
            let home = (chain.last?.end ?? outing.slot.end) + outing.trip.homeAfter
            if next.leave < evening { add(home, next.leave, before(next), next) }
        }
        if let dinner { add(dinner, bed, [.evening]) }
        return spans
    }

    /// The stretch open at `minute`, if any.
    static func window(at minute: Int, in spans: [WindowSpan]) -> WindowSpan? {
        spans.first { $0.contains(minute) }
    }

    private static func before(_ outing: Outing) -> [MissionWindow] {
        EventRef(outing.slot).map { [.before($0)] } ?? []
    }

    /// The outing's slot and the linked slots that follow it ("After {event}", gap included), in order.
    /// The planner leaves a linked item out when its event is not on the day, so its Bring goes too.
    private static func chain(from slot: Slot, in slots: [Slot]) -> [Slot] {
        var chain = [slot]
        while chain.count <= slots.count, let last = chain.last, let event = EventRef(last),
              let next = slots.first(where: { $0.after == event && $0.start >= last.end }) {
            chain.append(next)
        }
        return chain
    }
}

/// One circle in an open window (spec "Mission windows"): which window part it belongs to (done
/// marks are kept per window), and its picture and name.
public struct WindowMission: Identifiable, Hashable, Sendable {
    public var window: MissionWindow
    public var id: UUID
    public var name: String
    public var picture: String

    public init(window: MissionWindow, id: UUID, name: String, picture: String) {
        self.window = window
        self.id = id
        self.name = name
        self.picture = picture
    }
}

public extension DayPlanner {
    /// The kid's missions in a stretch, part by part: the morning routine's missions for the weekday
    /// (C5 order), then the outing's Bring checks and those of the events linked after it (swimming
    /// after school is checked before school). A Bring check whose picture is already there (the
    /// routine's "Pack bag" and Bring's bag) shows once. An outing with nothing to bring adds nothing,
    /// so a stretch of only that opens no window. School's own Bring (board G4) comes in `schoolBring`;
    /// the evening routine comes later.
    static func missions(in span: WindowSpan, routine: [Mission], items: [ScheduleItem],
                         weekday: Weekday, schoolBring: [ItemMission] = []) -> [WindowMission] {
        var result: [WindowMission] = []
        var pictures: Set<String> = []
        func add(_ window: MissionWindow, _ id: UUID, _ name: String, _ picture: String, once: Bool = true) {
            guard pictures.insert(picture).inserted || !once else { return }
            result.append(WindowMission(window: window, id: id, name: name, picture: picture))
        }
        func item(_ event: EventRef) -> ScheduleItem? {
            guard case let .item(id) = event else { return nil }
            return items.first { $0.id == id }
        }
        for part in span.parts {
            switch part {
            case .morning:
                for mission in routine.filter({ $0.days.contains(weekday) }).sorted(by: { $0.order < $1.order }) {
                    add(part, mission.id, mission.name, mission.picture, once: false)
                }
            case let .before(event):
                // School's own Bring (board G4) first when the outing is School.
                let own = event == .school ? schoolBring : []
                for thing in own + ([event] + span.linked).compactMap(item).flatMap(\.bring) {
                    add(part, thing.id, thing.name, thing.picture)
                }
            case .evening:
                continue
            }
        }
        return result
    }
}
