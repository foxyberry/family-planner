import Domain
import Foundation
import Strings

/// The side column beside the add/edit form: the kid's day with the new item in it (boards C3, C4).
public struct FormPreview: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public var slot: Slot
        /// The row of the item being added or edited.
        public var isNew: Bool

        public init(slot: Slot, isNew: Bool) {
            self.slot = slot
            self.isNew = isNew
        }

        /// "3:30"
        public var time: String { TimeText.clock(slot.start) }
    }

    /// "Kid A's Monday", "Monday" for both kids, or "Thursday 12 Nov" just once.
    public var heading: String
    /// Just once only: who it is for and when it goes.
    public var note: String?
    public var rows: [Row]
    /// Every week only: "On the clock every Monday from 9 Nov."
    public var summary: String?

    public init(heading: String, note: String?, rows: [Row], summary: String?) {
        self.heading = heading
        self.note = note
        self.rows = rows
        self.summary = summary
    }
}

extension ItemForm {
    /// The day the preview shows: the date just once, or the first picked weekday from today on.
    public func previewDay(today: Day, calendar: Calendar) -> Day {
        guard repeats == .weekly, let first = days.sorted().first else { return date }
        return (0..<7).lazy.map { today.adding(days: $0, calendar: calendar) }
            .first { $0.weekday(calendar) == first } ?? today
    }

    /// The preview for the form's kid (the first kid for both).
    /// `draftID`: the edited item's id, or an id kept for a new item; the draft replaces any item with it.
    /// `showsDraft`: false while the form has a problem, so only the day as it is shows.
    public func preview(kids: [Kid], routines: [Routine], items: [ScheduleItem], holidays: Set<Day>,
                        draftID: ScheduleItem.ID?, showsDraft: Bool, today: Day, calendar: Calendar) -> FormPreview {
        let kid: Kid? = switch audience {
        case let .kid(id): kids.first { $0.id == id }
        case .both: kids.first
        }
        let isBoth = audience == .both
        let day = previewDay(today: today, calendar: calendar)
        let weekday = DayText.name(day.weekday(calendar))
        let heading = repeats == .weekly
            ? (isBoth ? weekday : L10n.tr("preview.heading.kid", kid?.name ?? "", weekday))
            : DayText.long(day, calendar: calendar)
        let note = repeats == .once
            ? L10n.tr("preview.note", isBoth ? L10n.tr("preview.note.both") : kid?.name ?? "")
            : nil
        var rows: [FormPreview.Row] = []
        if let kid {
            var dayItems = items
            if let draftID {
                dayItems.removeAll { $0.id == draftID }
                if showsDraft { dayItems.append(item(id: draftID, today: today)) }
            }
            rows = DayPlanner.slots(on: day, kid: kid, routines: routines, items: dayItems, holidays: holidays,
                                    calendar: calendar)
                .filter { $0.kind != .sleep }
                .map { slot in
                    let isNew = draftID.map { slot.source == .weekly($0) || slot.source == .once($0) } ?? false
                    return FormPreview.Row(slot: slot, isNew: isNew)
                }
        }
        return FormPreview(heading: heading, note: note, rows: rows,
                           summary: summaryCaption(today: today, calendar: calendar))
    }
}
