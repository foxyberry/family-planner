import DesignSystem
import Domain
import Foundation
import Strings

/// A row of the "Next" list or the day-off item (boards E1, E3).
public struct NextRow: Equatable, Sendable {
    public var iconName: String
    public var title: String
    public var start: Int
    public var end: Int
}

/// What the home screen says about a kid's day, kept free of views so the copy rules are tested.
public enum HomeModel {
    public static func sectors(_ slots: [Slot], minute: Int) -> [ClockSector] {
        slots.map { slot in
            let priority = switch slot.source {
            case .routine: 0
            case .weekly: 1
            case .once: 2
            }
            return ClockSector(start: slot.start, end: slot.end, style: ClockSlotStyle(rawValue: slot.kind.rawValue)!,
                               iconName: slot.iconName, isCurrent: slot.start <= minute && minute < slot.end,
                               showsStar: slot.showsStar, priority: priority)
        }
    }

    /// The NOW rule: the slot's name "until" its end; in a gap "Free time" until the next slot;
    /// with no slots at all "Nothing planned". Sleep before midnight runs on to the morning's wake-up.
    public static func hub(_ slots: [Slot], minute: Int) -> PieClock.Hub {
        guard !slots.isEmpty else { return PieClock.Hub(title: L10n.tr("home.hub.nothing"), subtitle: nil) }
        let now = DayPlanner.now(at: minute, in: slots)
        if let current = now.current {
            return PieClock.Hub(title: current.title, subtitle: L10n.tr("home.hub.until", TimeText.clock(end(of: current, in: slots))))
        }
        return PieClock.Hub(title: L10n.tr("home.hub.free"),
                            subtitle: now.next.map { L10n.tr("home.hub.until", TimeText.clock($0.start)) })
    }

    /// Up to `limit` slots after the current one (or after now in a gap).
    public static func nextRows(_ slots: [Slot], minute: Int, limit: Int = 2) -> [NextRow] {
        let after = DayPlanner.now(at: minute, in: slots).current?.end ?? minute
        return slots.filter { $0.start >= after && $0.start > minute }.prefix(limit)
            .map { NextRow(iconName: $0.iconName, title: $0.title, start: $0.start, end: $0.end) }
    }

    /// The next every-week or just-once item that has not ended (board E3 shows only one).
    public static func nextItem(_ slots: [Slot], minute: Int) -> NextRow? {
        slots.first { $0.source != .routine && $0.end > minute }
            .map { NextRow(iconName: $0.iconName, title: $0.title, start: $0.start, end: $0.end) }
    }

    public static func accessibilityLabel(kidName: String, slots: [Slot], minute: Int) -> String {
        let current = DayPlanner.now(at: minute, in: slots).current?.title ?? L10n.tr("home.hub.free")
        return L10n.tr("home.clock.label", kidName, TimeText.clock(minute), current)
    }

    /// A slot that ends at midnight continues into the same kind of slot that starts the day.
    private static func end(of slot: Slot, in slots: [Slot]) -> Int {
        guard slot.end == 1440, let first = slots.first, first.start == 0, first.kind == slot.kind else { return slot.end }
        return first.end
    }
}
