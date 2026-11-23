import DesignSystem
import Domain
import Foundation
import KitArt
import Strings

/// The one thing next on a kid's clock (spec "Now and next on home"), drawn as a Next row.
public struct NextItem: Equatable, Sendable {
    public var iconName: String
    public var title: String
    public var start: Int
    public var end: Int
    public var kind: SlotKind
    /// A just-once item keeps its star sticker on the picture.
    public var showsStar: Bool
    /// The row's time line: "in 45 min" within 60 minutes, else "at 7:30 am" (`HomeModel.nextLine`).
    public var line: String

    /// The row's picture (an unknown name shows play).
    public var picture: KitSlot { KitSlot(iconName: iconName) }
}

/// Spec "Kid A, which row" (layout v74; boards A1n, A1z): Kid A's Tomorrow row, for the next day
/// with a plan: its first outing ("leave {h:mm}"), else its first thing after the opening Sleep
/// ("at {h:mm}"). `inDays` is 1 for tomorrow; a later day (nothing planned before it) is named by
/// its weekday 2–6 days away, by its short date from 7 (spec #261).
public struct AheadRow: Equatable, Sendable {
    public var item: NextItem
    public var inDays: Int
    public var day: Day
    public var weekday: Weekday

    public init(item: NextItem, inDays: Int, day: Day, weekday: Weekday) {
        self.item = item
        self.inDays = inDays
        self.day = day
        self.weekday = weekday
    }
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
            return ClockSector(start: slot.start, end: slot.end, style: ClockSlotStyle(rawValue: slot.kind.rawValue) ?? .play,
                               iconName: slot.kind == .free || slot.iconName.isEmpty ? nil : slot.iconName, isCurrent: slot.start <= minute && minute < slot.end,
                               showsStar: slot.showsStar, priority: priority)
        }
    }

    /// Spec "Kid A, which row" (layout v74): what a day's Tomorrow row names: the day's first outing
    /// with its leave time (the same `Outing.leave` as the Leave row), else its first thing after the
    /// opening Sleep with its start; nil for a day with nothing to name.
    public static func dayAhead(_ slots: [Slot]) -> NextItem? {
        if let outing = DayPlanner.nextOuting(in: slots, after: -1) {
            let slot = outing.slot
            return NextItem(iconName: slot.iconName, title: slot.title, start: slot.start, end: end(of: slot, in: slots),
                            kind: slot.kind, showsStar: slot.showsStar,
                            line: L10n.tr("home.tomorrow.leave_at", TimeText.withPeriod(outing.leave)))
        }
        let wake = slots.first { $0.start == 0 && $0.kind == .sleep }?.end ?? 0
        guard let slot = slots.first(where: { $0.start >= wake && shows($0, in: slots) }) else { return nil }
        return item(slot, in: slots, line: L10n.tr("home.next.at", TimeText.withPeriod(slot.start)))
    }

    /// A slot the Next row can name: not free time, not a template slot that only resumes.
    private static func shows(_ slot: Slot, in slots: [Slot]) -> Bool {
        slot.kind != .free && !onlyContinues(slot, in: slots)
    }

    private static func item(_ slot: Slot, in slots: [Slot], line: String) -> NextItem {
        NextItem(iconName: slot.iconName, title: slot.title, start: slot.start, end: end(of: slot, in: slots),
                 kind: slot.kind, showsStar: slot.showsStar, line: line)
    }

    /// A template slot that starts where an item ends, with a piece of the same slot just before
    /// that item: the template only resumes there.
    private static func onlyContinues(_ slot: Slot, in slots: [Slot]) -> Bool {
        guard slot.source == .routine,
              let item = slots.first(where: { $0.end == slot.start && $0.source != .routine }) else { return false }
        return slots.contains { $0.source == .routine && $0.title == slot.title && $0.kind == slot.kind && $0.end == item.start }
    }

    /// A slot that ends at midnight continues into the same kind of slot that starts the day.
    private static func end(of slot: Slot, in slots: [Slot]) -> Int {
        guard slot.end == 1440, let first = slots.first, first.start == 0, first.kind == slot.kind else { return slot.end }
        return first.end
    }
}
