import Foundation

/// "This day" or "All days" (spec "Edit scope"): every change on the G1 clock carries the scope it
/// was made in, and Save writes each change by its own scope.
public enum EditScope: Hashable, Sendable { case thisDay, allDays }

/// A change to the day template, kept with its scope so Save can write the All days ones onto the
/// day type's template (from G5's date) and the This day ones as the day's own template.
public struct TemplateChange: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// A template knob moved (a drag or a typed time), by its minutes.
        case move(from: Int, to: Int)
        /// "Remove": the slice over this span became free time.
        case free(start: Int, end: Int)
        /// "Skip this day" or "Bring back" on the slice starting at `start` (always This day).
        case skip(start: Int, skipped: Bool)
    }

    public var scope: EditScope
    public var kind: Kind

    public init(_ scope: EditScope, _ kind: Kind) {
        self.scope = scope
        self.kind = kind
    }
}

/// An every-week, every-month or just-once item on the G1 clock (spec G1 "One card for everything on
/// the clock"): its times on the day, and what the grown-up did to it before Save. It sits on top of
/// the day template; the template underneath stays as it is.
public struct ClockItem: Equatable, Sendable, Identifiable {
    public var id: ScheduleItem.ID
    public var title: String
    /// A `KitSlot` raw value.
    public var iconName: String
    public var start: Int
    public var end: Int
    /// Every week or every month (This day / All days); false for a just-once item.
    public var isRepeating: Bool
    /// Every month: its Remove asks "every month".
    public var isMonthly: Bool
    /// Placed after another event ("after School"): its edges follow that event, so they have no knobs.
    public var isAnchored: Bool
    /// "Skip this day" (This day): faded on the clock, "Bring back" on its card.
    public var isSkipped: Bool
    /// "Remove" (All days, or a just-once item): off the clock until Undo.
    public var isRemoved: Bool
    /// Added on the clock ("+") and not saved yet.
    public var isNew: Bool
    /// The scope its times were last changed in (a drag or a typed time); nil while they are as saved.
    public var retimeScope: EditScope?

    public init(id: ScheduleItem.ID, title: String, iconName: String, start: Int, end: Int, isRepeating: Bool,
                isMonthly: Bool = false, isAnchored: Bool = false, isSkipped: Bool = false, isRemoved: Bool = false,
                isNew: Bool = false) {
        self.isMonthly = isMonthly
        self.id = id
        self.title = title
        self.iconName = iconName
        self.start = start
        self.end = end
        self.isRepeating = isRepeating
        self.isAnchored = isAnchored
        self.isSkipped = isSkipped
        self.isRemoved = isRemoved
        self.isNew = isNew
    }

    /// A new item's scope is its kind: just once on This day, every week on All days.
    public var newScope: EditScope { isRepeating ? .allDays : .thisDay }

    /// The slice colour an item has (as `ScheduleItem.kind`).
    public var kind: SlotKind { isRepeating ? .afterSchool : .event }
}

/// One piece drawn on the G1 clock: a day-template slice (or the part of it an item leaves showing)
/// or an item.
public struct ClockSlice: Equatable, Sendable {
    public enum Source: Hashable, Sendable {
        /// `TemplateEdit.blocks[index]`.
        case block(Int)
        case item(ScheduleItem.ID)
    }

    public var source: Source
    public var title: String
    public var iconName: String
    public var kind: SlotKind
    public var start: Int
    public var end: Int
    public var isSkipped: Bool
    /// 0 day template, 1 every week or month, 2 just once (the kid clock's order).
    public var priority: Int

    public init(source: Source, title: String, iconName: String, kind: SlotKind, start: Int, end: Int,
                isSkipped: Bool, priority: Int) {
        self.source = source
        self.title = title
        self.iconName = iconName
        self.kind = kind
        self.start = start
        self.end = end
        self.isSkipped = isSkipped
        self.priority = priority
    }

    public var isItem: Bool { if case .item = source { true } else { false } }
}

/// A knob on the rim of the G1 clock: where two drawn slices touch.
public struct DayKnob: Equatable, Sendable {
    /// What a drag of the knob moves.
    public enum Edge: Hashable, Sendable {
        /// The shared edge of `blocks[before]` and the next template slice.
        case blocks(before: Int)
        /// An item's start over the slice before it (the template there stays as it is).
        case itemStart(ScheduleItem.ID)
        case itemEnd(ScheduleItem.ID)
        /// One item ends where another starts: both move.
        case items(end: ScheduleItem.ID, start: ScheduleItem.ID)
    }

    public var minute: Int
    public var edge: Edge
    public var before: ClockSlice.Source
    public var after: ClockSlice.Source
    /// Spec "Add between two slices": the "+" shows on every shared knob of two slices that are not
    /// free time, an item's edges too (user, 2026-11-21). Where two "+" would touch, the screen
    /// puts the later one on an inner ring (`EditClock.placed`).
    public var showsAdd: Bool

    public init(minute: Int, edge: Edge, before: ClockSlice.Source, after: ClockSlice.Source, showsAdd: Bool) {
        self.minute = minute
        self.edge = edge
        self.before = before
        self.after = after
        self.showsAdd = showsAdd
    }
}

public extension DayPlanner {
    /// The kid's items on `day` for the G1 clock, placed as on the kid clock ("after" chains), with
    /// the ones skipped this day kept (faded, so "Bring back" can reach them).
    static func clockItems(on day: Day, kid: Kid.ID, routines: [Routine], items: [ScheduleItem],
                           holidays: Set<Day>, calendar: Calendar) -> [ClockItem] {
        let routine = template(for: kid, on: day, routines: routines, holidays: holidays, calendar: calendar)
        let occurring = items.compactMap { item -> ScheduleItem? in
            var open = item
            open.skippedDays.remove(day)
            return occurs(open, on: day, kid: kid, holidays: holidays, calendar: calendar) ? open.on(day) : nil
        }
        let schoolEnd = routine?.blocks.first { $0.kind == .school && !$0.isSkipped }?.end
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return placed(occurring, schoolEnd: schoolEnd).map { item, start in
            let original = byID[item.id]
            return ClockItem(id: item.id, title: item.title, iconName: item.iconName, start: start,
                             end: start + item.end - item.start, isRepeating: item.isRepeating,
                             isMonthly: item.isMonthly, isAnchored: original?.after != nil,
                             isSkipped: original?.skippedDays.contains(day) ?? false)
        }
        .sorted { $0.start < $1.start }
    }
}

/// What a G1 Save writes for the items on the clock (spec G1 "One card for everything on the clock",
/// "Tapping +"): every change waits for Save, then becomes item writes.
public enum ClockSave {
    public struct Writes: Equatable, Sendable {
        public var saved: [ScheduleItem]
        public var deleted: [ScheduleItem.ID]

        public init(saved: [ScheduleItem] = [], deleted: [ScheduleItem.ID] = []) {
            self.saved = saved
            self.deleted = deleted
        }

        public var isEmpty: Bool { saved.isEmpty && deleted.isEmpty }
    }

    /// - `items`: the clock's items now; `saved`: as they were at the last save (or load).
    /// - Each change is written by the scope it was made in: new times by `retimeScope` (This day
    ///   keeps them for `day`, All days from `from`), a skip is this day, a remove ends the series
    ///   from `from` (a just-once item is deleted), an add is a just-once item on `day` or, when
    ///   added on All days, an every-week item on `day`'s weekday from `from`. `from` is G5's date,
    ///   asked only when there are All days changes.
    public static func writes(items: [ClockItem], saved: [ClockItem], originals: [ScheduleItem], kid: Kid.ID,
                              day: Day, from: Day, calendar: Calendar, newID: () -> UUID) -> Writes {
        var writes = Writes()
        let before = Dictionary(saved.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for draft in items {
            guard let original = originals.first(where: { $0.id == draft.id }) else {
                if draft.isNew && !draft.isRemoved { writes.saved.append(added(draft, kid: kid, day: day, from: from, calendar: calendar)) }
                continue
            }
            let was = before[draft.id] ?? draft
            if draft.isRemoved {
                guard !was.isRemoved else { continue }
                if let range = original.recurrence.range, from > range.from {
                    writes.saved.append(SeriesEdits.ending(original, before: from, calendar: calendar))
                } else {
                    writes.deleted.append(original.id)
                }
                continue
            }
            var parts = [original]
            if draft.start != was.start || draft.end != was.end {
                parts = retimed(original, to: draft, day: day, allDays: draft.retimeScope == .allDays, from: from,
                                calendar: calendar, newID: newID)
            }
            if draft.isSkipped != was.isSkipped {
                parts = parts.map {
                    draft.isSkipped ? SeriesEdits.skipping($0, day: day) : SeriesEdits.unskipping($0, day: day)
                }
            }
            if parts != [original] { writes.saved += parts }
        }
        return writes
    }

    private static func added(_ draft: ClockItem, kid: Kid.ID, day: Day, from: Day, calendar: Calendar) -> ScheduleItem {
        let recurrence: Recurrence = draft.isRepeating
            ? .weekly([day.weekday(calendar)], from: from, until: nil) : .once(day)
        return ScheduleItem(id: draft.id, title: draft.title, iconName: draft.iconName, audience: .kid(kid),
                            start: draft.start, end: draft.end, recurrence: recurrence, skippedDays: [],
                            skipsHolidays: false, showsStar: !draft.isRepeating,
                            runsEnd: draft.isRepeating ? RunsEnd.none : nil)
    }

    /// New times: a just-once item moves; a series changes this day only, or from `from` on.
    private static func retimed(_ original: ScheduleItem, to draft: ClockItem, day: Day, allDays: Bool, from: Day,
                                calendar: Calendar, newID: () -> UUID) -> [ScheduleItem] {
        guard original.isRepeating else {
            var moved = original
            moved.start = draft.start
            moved.end = draft.end
            return [moved]
        }
        if allDays {
            var edit = original
            edit.start = draft.start
            edit.end = draft.end
            return SeriesEdits.splitting(original, with: edit, from: from, newID: newID(), calendar: calendar).items
        }
        var edit = original.on(day)
        edit.start = draft.start
        edit.end = draft.end
        return [SeriesEdits.changing(original, on: day, to: edit)]
    }
}
