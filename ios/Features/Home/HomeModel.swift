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

/// What is on now for a kid without the clock (Kid B's Now row): its picture, title and "until …".
public struct NowItem: Equatable, Sendable {
    public var picture: KitSlot
    public var title: String
    /// "until 4:00 pm"; nil when nothing is on now and nothing is later today (the row has no time line).
    public var line: String?
    public var showsStar: Bool

    public init(picture: KitSlot, title: String, line: String?, showsStar: Bool) {
        self.picture = picture
        self.title = title
        self.line = line
        self.showsStar = showsStar
    }
}

/// Board A1n "Tomorrow" row: tomorrow's first outing, "Tomorrow" over "School, leave 7:25 am".
public struct TomorrowRow: Equatable, Sendable {
    public var iconName: String
    public var title: String { L10n.tr("home.tomorrow") }
    public var line: String
    /// The row's picture (an unknown name shows play).
    public var picture: KitSlot { KitSlot(iconName: iconName) }

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
    /// (Play after Weekend school). `skipping` (board E1, under the Leave row) passes over the
    /// outing's item to the thing after it. With `tomorrow` (Kid B, board A1n) Next looks into
    /// tomorrow only while the slot on now runs to midnight (spec "States", v70): then it is the
    /// first thing after the night's sleep ("Breakfast"); otherwise it stays within today.
    public static func next(_ slots: [Slot], minute: Int, tomorrow: [Slot] = [], skipping skipped: Slot? = nil) -> NextItem? {
        let current = DayPlanner.now(at: minute, in: slots).current
        let after = current?.end ?? minute
        let first = { (after: Int) in slots.first { $0.start >= after && $0.start > minute && shows($0, in: slots) } }
        if var slot = first(after) {
            if slot == skipped {
                guard let later = first(slot.end) else { return nil }
                slot = later
            }
            return item(slot, in: slots, minutesAway: slot.start - minute)
        }
        guard let current, current.kind != .free, current.end == 1440 else { return nil }
        // Tomorrow's night is skipped: its opening Sleep, or tonight's slot running on past
        // midnight into tomorrow's first slot of the same kind.
        let night = tomorrow.first { slot in
            slot.start == 0 && (slot.kind == .sleep || slot.kind == current.kind)
        }
        let wake = night?.end ?? 0
        return tomorrow.first { $0.start >= wake && shows($0, in: tomorrow) }
            .map { item($0, in: tomorrow, minutesAway: $0.start + 1440 - minute) }
    }

    /// The Next row's time line (spec "The row", user 2026-11-22): "in {n} min" while the start is
    /// 60 minutes or less away, else "at {h:mm am/pm}". Never "1h 20m" (that stays for Leave and Bed).
    public static func nextLine(start: Int, minutesAway: Int) -> String {
        minutesAway <= 60 ? L10n.tr("home.next.in_min", "\(minutesAway)") : L10n.tr("home.next.at", TimeText.withPeriod(start))
    }

    /// Kid B's Now row (spec "Kid B block"): the slot on now "until" its end; with nothing on now (or
    /// free time) the play picture and "Free time" until the next slot starts, with no time line when
    /// nothing is later; an empty day reads "Nothing planned" as the hub does (spec "States", v70).
    /// With `tomorrow`, a slot running past midnight ends at tomorrow's wake-up (the Next row's day).
    public static func now(_ slots: [Slot], minute: Int, tomorrow: [Slot] = []) -> NowItem {
        guard !slots.isEmpty else {
            return NowItem(picture: .actPlay, title: L10n.tr("home.hub.nothing"), line: nil, showsStar: false)
        }
        let now = DayPlanner.now(at: minute, in: slots)
        let until = { (minute: Int) in L10n.tr("home.hub.until", TimeText.withPeriod(minute)) }
        let nextDay = tomorrow.isEmpty ? slots : tomorrow
        if let current = now.current, current.kind != .free {
            return NowItem(picture: KitSlot(iconName: current.iconName), title: current.title,
                           line: until(end(of: current, in: nextDay)), showsStar: current.showsStar)
        }
        let freeUntil = now.current.map { end(of: $0, in: nextDay) } ?? now.next?.start
        return NowItem(picture: .actPlay, title: L10n.tr("home.hub.free"), line: freeUntil.map(until), showsStar: false)
    }

    /// "Bed in" and the minutes to `next`, when it is Sleep (board A1n); `nil` over 3 hours or with
    /// nothing next.
    public struct TimeLeft: Equatable, Sendable {
        public var label: String
        public var minutes: Int

        public init(label: String, minutes: Int) {
            self.label = label
            self.minutes = minutes
        }

        /// "38 min", "1h 20m", "−2 min".
        public var text: String { TimeLeftText.short(minutes: minutes) }
        public var isLate: Bool { TimeLeftText.isLate(minutes: minutes) }
    }

    public static func bedIn(to next: NextItem?, minute: Int) -> TimeLeft? {
        guard let next, next.kind == .sleep, next.start - minute <= 180 else { return nil }
        return TimeLeft(label: L10n.tr("home.next.bed_in"), minutes: next.start - minute)
    }

    /// A slot the Next row can name: not free time, not a template slot that only resumes.
    private static func shows(_ slot: Slot, in slots: [Slot]) -> Bool {
        slot.kind != .free && !onlyContinues(slot, in: slots)
    }

    private static func item(_ slot: Slot, in slots: [Slot], minutesAway: Int) -> NextItem {
        NextItem(iconName: slot.iconName, title: slot.title, start: slot.start, end: end(of: slot, in: slots),
                 kind: slot.kind, showsStar: slot.showsStar,
                 line: nextLine(start: slot.start, minutesAway: minutesAway))
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
