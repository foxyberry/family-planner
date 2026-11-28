import Foundation

/// How a kid comes home from the last event of a chain (spec "Events: one shape", issue 024). Only
/// `pickup` shows on home: a grown-up leaves at end − `homeAfter` to fetch the kid.
public enum WayHome: String, Codable, CaseIterable, Sendable {
    case none, pickup, bus, walk
}

/// Which event's lists a row, a screen or a done mark means (issue 024; spec "Event lists", done
/// key): an item or School by its event; a template outing, which has no id, by its kind and title,
/// so a same-day retime keeps its marks, with its start only when the day has two such slots.
public enum ListRef: Hashable, Codable, Sendable {
    case event(EventRef)
    case block(SlotKind, String, start: Int?)

    /// `slot`'s list among the day's `slots`.
    public init(_ slot: Slot, in slots: [Slot]) {
        if let event = EventRef(slot) {
            self = .event(event)
        } else {
            let twin = slots.contains { $0 != slot && $0.source == .routine && $0.kind == slot.kind && $0.title == slot.title }
            self = .block(slot.kind, slot.title, start: twin ? slot.start : nil)
        }
    }
}

/// Which of an outing's two lists.
public enum ListKind: String, Codable, Sendable {
    case before, after
}

/// An outing's lists and way home (spec "Events: one shape", issue 024). Bundles belong to a kid, so a
/// kid's list holds that kid's bundles; Bring (kept where it was) and the after missions are shared by
/// every kid on the event. All empty by default.
public struct EventLists: Hashable, Codable, Sendable {
    /// Bundles on the before list.
    public var before: [MissionBundle.ID]
    /// Bundles on the after list (only the last event of a chain has one).
    public var afterBundles: [MissionBundle.ID]
    /// Things to do back home, shared by every kid on the event.
    public var afterMissions: [ItemMission]
    public var wayHome: WayHome
    /// The way home's minutes ("Takes", board F7): 0–90 in steps of 5. A pickup leaves at end − this.
    public var homeAfter: Int

    public init(before: [MissionBundle.ID] = [], afterBundles: [MissionBundle.ID] = [],
                afterMissions: [ItemMission] = [], wayHome: WayHome = .none, homeAfter: Int = 0) {
        self.before = before
        self.afterBundles = afterBundles
        self.afterMissions = afterMissions
        self.wayHome = wayHome
        self.homeAfter = StepRange.homeAfter.clamp(homeAfter / 5 * 5)
    }

    private enum CodingKeys: String, CodingKey { case before, afterBundles, afterMissions, wayHome, homeAfter }

    /// Any part missing (a later field) loads empty.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(before: try c.decodeIfPresent([MissionBundle.ID].self, forKey: .before) ?? [],
                  afterBundles: try c.decodeIfPresent([MissionBundle.ID].self, forKey: .afterBundles) ?? [],
                  afterMissions: try c.decodeIfPresent([ItemMission].self, forKey: .afterMissions) ?? [],
                  wayHome: try c.decodeIfPresent(WayHome.self, forKey: .wayHome) ?? .none,
                  homeAfter: try c.decodeIfPresent(Int.self, forKey: .homeAfter) ?? 0)
    }
}

/// One thing on a list: a mission or a thing to bring.
public struct ListEntry: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case mission, bring }
    public var id: UUID
    public var name: String
    /// A `KitSlot` raw value.
    public var picture: String
    public var kind: Kind

    public init(id: UUID, name: String, picture: String, kind: Kind) {
        self.id = id
        self.name = name
        self.picture = picture
        self.kind = kind
    }
}

/// The list rules (spec "Events: one shape" → Lists): pure, on a day's slots.
public enum EventListRules {
    /// The events linked after `slot` on its day, in chain order (a linked event starts when the one
    /// before it ends).
    public static func linked(after slot: Slot, in slots: [Slot]) -> [Slot] {
        var chain: [Slot] = [], current = slot
        while let next = slots.first(where: { $0.after == EventRef(current) && $0 != current }) {
            guard !chain.contains(next) else { break }
            chain.append(next)
            current = next
        }
        return chain
    }

    /// The last event of `slot`'s chain on its day (itself when nothing is linked after it): it carries
    /// the way home and the after list.
    public static func chainEnd(of slot: Slot, in slots: [Slot]) -> Slot {
        linked(after: slot, in: slots).last ?? slot
    }

    /// A kid's before list: the kid's bundles' missions that are on `weekday` (bundle order, then circle
    /// order, each mission once), then Bring (its own, then every event linked after it), each picture
    /// once and none whose picture a mission already shows. A linked event
    /// (one that follows another) holds only its missions: its Bring is packed on the chain's first list.
    public static func before(kid: Kid.ID, slot: Slot, in slots: [Slot], bundles: [MissionBundle],
                              weekday: Weekday) -> [ListEntry] {
        var entries = missions(kid: kid, ids: slot.lists.before, bundles: bundles, weekday: weekday)
        guard slot.after == nil else { return entries }
        var pictures = Set(entries.map(\.picture))
        for thing in ([slot] + linked(after: slot, in: slots)).flatMap(\.bring) where pictures.insert(thing.picture).inserted {
            entries.append(ListEntry(id: thing.id, name: thing.name, picture: thing.picture, kind: .bring))
        }
        return entries
    }

    /// A kid's after list on the chain's last event: the kid's after bundles on `weekday`, then the
    /// shared after missions, each picture once. Empty on an event that is not the end of its chain.
    public static func after(kid: Kid.ID, slot: Slot, in slots: [Slot], bundles: [MissionBundle],
                             weekday: Weekday) -> [ListEntry] {
        guard chainEnd(of: slot, in: slots) == slot else { return [] }
        var entries = missions(kid: kid, ids: slot.lists.afterBundles, bundles: bundles, weekday: weekday)
        var pictures = Set(entries.map(\.picture))
        for thing in slot.lists.afterMissions where pictures.insert(thing.picture).inserted {
            entries.append(ListEntry(id: thing.id, name: thing.name, picture: thing.picture, kind: .mission))
        }
        return entries
    }

    private static func missions(kid: Kid.ID, ids: [MissionBundle.ID], bundles: [MissionBundle],
                                 weekday: Weekday) -> [ListEntry] {
        var seen: Set<UUID> = [], entries: [ListEntry] = []
        for id in ids {
            guard let bundle = bundles.first(where: { $0.id == id && $0.kid == kid }) else { continue }
            for mission in bundle.missions where mission.days.contains(weekday) && seen.insert(mission.id).inserted {
                entries.append(ListEntry(id: mission.id, name: mission.name, picture: mission.picture, kind: .mission))
            }
        }
        return entries
    }
}
