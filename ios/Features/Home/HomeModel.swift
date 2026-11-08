import DesignSystem
import Domain
import Foundation
import Strings

/// A row of the "Next" list or the day-off item (boards E1, E3).
/// The one thing next on a kid's clock (spec "Now and next on home").
public struct NextRow: Equatable, Sendable {
    public var iconName: String
    public var title: String
    public var start: Int
    public var end: Int
    public var kind: SlotKind
    /// A just-once item keeps its star sticker on the picture.
    public var showsStar: Bool

    /// "at 7:30 am": the start only; the range is on the clock.
    public var at: String { L10n.tr("home.next.at", TimeText.withPeriod(start)) }
}

/// Board A1n "Tomorrow" row: tomorrow's first outing, "Tomorrow" over "School, leave 7:25 am".
public struct TomorrowRow: Equatable, Sendable {
    public var iconName: String
    public var title: String { L10n.tr("home.tomorrow") }
    public var line: String

    public init(_ outing: Outing) {
        iconName = outing.slot.iconName
        line = L10n.tr("home.tomorrow.leave", outing.slot.title, TimeText.withPeriod(outing.leave))
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

    /// The hub (board A1): the slot's name "until" its end (12-hour with am/pm);
    /// in a gap or free time "Free time" until the next slot; with no slots at all "Nothing planned".
    /// Sleep before midnight runs on to the morning's wake-up.
    public static func hub(_ slots: [Slot], minute: Int) -> PieClock.Hub {
        guard !slots.isEmpty else { return PieClock.Hub(title: L10n.tr("home.hub.nothing"), subtitle: nil) }
        let now = DayPlanner.now(at: minute, in: slots)
        let until = { (minute: Int) in L10n.tr("home.hub.until", TimeText.withPeriod(minute)) }
        if let current = now.current {
            let title = current.kind == .free ? L10n.tr("home.hub.free") : current.title
            return PieClock.Hub(title: title, subtitle: until(end(of: current, in: slots)))
        }
        return PieClock.Hub(title: L10n.tr("home.hub.free"), subtitle: now.next.map { until($0.start) })
    }

    /// Spec "Now and next on home": the next thing after the current one, of any kind, after the
    /// priority rule. Free time is skipped, and so is a slot that only continues after an item ends
    /// (Play after Weekend school).
    public static func next(_ slots: [Slot], minute: Int) -> NextRow? {
        let after = DayPlanner.now(at: minute, in: slots).current?.end ?? minute
        return slots.first { $0.start >= after && $0.start > minute && $0.kind != .free && !onlyContinues($0, in: slots) }
            .map { NextRow(iconName: $0.iconName, title: $0.title, start: $0.start, end: end(of: $0, in: slots),
                           kind: $0.kind, showsStar: $0.showsStar) }
    }

    /// "in" / "Bed in" and the minutes to `next`; `nil` over 3 hours or with nothing next.
    public struct TimeLeft: Equatable, Sendable {
        public var label: String
        public var minutes: Int

        public init(label: String, minutes: Int) {
            self.label = label
            self.minutes = minutes
        }
    }

    public static func timeLeft(to next: NextRow?, minute: Int) -> TimeLeft? {
        guard let next, next.start - minute <= 180 else { return nil }
        return TimeLeft(label: next.kind == .sleep ? L10n.tr("home.next.bed_in") : L10n.tr("home.next.in"),
                        minutes: next.start - minute)
    }

    /// A template slot that starts where an item ends, with a piece of the same slot just before
    /// that item: the template only resumes there.
    private static func onlyContinues(_ slot: Slot, in slots: [Slot]) -> Bool {
        guard slot.source == .routine,
              let item = slots.first(where: { $0.end == slot.start && $0.source != .routine }) else { return false }
        return slots.contains { $0.source == .routine && $0.title == slot.title && $0.kind == slot.kind && $0.end == item.start }
    }

    public static func accessibilityLabel(kidName: String, day: String, slots: [Slot], minute: Int) -> String {
        let now = DayPlanner.now(at: minute, in: slots).current
        let current = now.map { $0.kind == .free ? L10n.tr("home.hub.free") : $0.title } ?? L10n.tr("home.hub.free")
        return L10n.tr("home.clock.label", kidName, day, TimeText.withPeriod(minute), current)
    }

    /// A slot that ends at midnight continues into the same kind of slot that starts the day.
    private static func end(of slot: Slot, in slots: [Slot]) -> Int {
        guard slot.end == 1440, let first = slots.first, first.start == 0, first.kind == slot.kind else { return slot.end }
        return first.end
    }
}
