import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import KitArt
import Localization
import ScheduleStore
import SchoolDirectory
import Strings

/// G1 · The day on the clock (spec "G1"): a grown-up edits a kid's day on a real date. The day
/// template and the items on top of it share one clock, one slice card and one Undo (spec C6 "One
/// card for everything on the clock"); the rules live in `TemplateEdit`. Save writes the template
/// for this day only or for all days from a date (spec "Edit scope"), and the items' changes
/// (`ClockSave`).
@Reducer
public struct OurDayFeature {
    /// Every picture a new slice can have (user, 2026-11-09: all of them, sleep too), in day order.
    public static let pictures: [KitSlot] = [
        .actSleep, .pyjamas, .teddy, .sun, .toilet, .toothbrush, .washFace, .hairBrush, .shirt, .actBreakfast,
        .milk, .backpack, .shoe, .actSchool, .homework, .actPlay, .blocks, .playground, .snack, .tv, .actStory,
        .actCCA, .actArt, .actMusic, .actPiano, .actDance, .actFootball, .actSwim, .actLanguageSchool, .actChurch,
        .actDinner, .actShower, .cake, .doctor,
    ]

    /// Board G1f: the seven pictures a new slice offers before "More".
    public static let suggested: [KitSlot] = [.actPlay, .snack, .actStory, .homework, .tv, .actArt, .actMusic]
    /// Slice names keep the C5 limit (14 characters).
    static let longestName = 14

    /// A new item being filled in from a "+" (board G1f): on the clock once a picture is picked.
    public struct NewSlice: Equatable, Sendable {
        public var id: ScheduleItem.ID
        public var start: Int
        public var end: Int
        public var name: String
        public var iconName: String?
        /// Its tabs: just once (This day) or every week (All days); the item on the clock keeps it.
        public var scope: Scope
        /// A picture was picked, so the item is on the clock (Undo takes it back).
        public var isOnClock = false
        /// The grown-up typed a name; a later picture no longer renames the item.
        public var nameIsTyped = false
        /// "More" shows every day picture.
        public var isPickingMore = false

        public init(id: ScheduleItem.ID, start: Int, end: Int, scope: Scope, name: String = "", iconName: String? = nil) {
            self.id = id
            self.scope = scope
            self.start = start
            self.end = end
            self.name = name
            self.iconName = iconName
        }
    }

    /// Haptic moments for the view (board C6): a 5-minute step, a step onto the hour, a stop at a limit.
    public struct Haptics: Equatable, Sendable {
        public var steps = 0
        public var hours = 0
        public var bumps = 0
    }

    /// "This day" or "All days" (spec "Edit scope"): each change carries the scope it was made in.
    public typealias Scope = EditScope

    /// A knob being dragged: what it moves and how far it may go (fixed when the drag starts).
    public struct Drag: Equatable, Sendable {
        public var edge: DayKnob.Edge
        public var range: ClosedRange<Int>
        /// The knob's minute when the drag began.
        public var from: Int
    }

    /// The one action under the slice card's times (spec C6 "One card"): "Skip this day" on This
    /// day, "Remove" on All days and on a just-once item.
    public enum SliceAction: Equatable, Sendable { case skip, remove }

    /// Board G1: the ConfirmCard before an every-week or every-month item or a just-once item is
    /// removed (School's Remove opens G7 instead).
    public enum Removing: Equatable, Sendable {
        case series(ScheduleItem.ID)
        case once(ScheduleItem.ID)
    }

    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var kid: Kid.ID
        /// The date on the clock (board G1's day button).
        public var day: Day
        /// The This day / All days tabs: the scope the next change on a slice is made in.
        public var scope: Scope = .thisDay
        /// Board G5 on an All days save: the card's choice while it is open, and its date.
        public var fromWhen: ItemEditorFeature.FromWhen?
        public var fromWhenDate: Day
        /// Board G1c: the day picker's first date (a Monday) while it is open.
        public var pickerStart: Day?
        /// The kids' school days off and public holidays, for the day's template.
        public var family = FamilyCalendar()
        public var today: Day
        public var kids: [Kid] = []
        public var routines: [Routine] = []
        public var edit = TemplateEdit(blocks: [])
        /// The slice the card shows: a template slice or an item.
        public var selected: ClockSlice.Source?
        public var drag: Drag?
        public var dragOrigin: Int?
        public var message: String?
        public var newSlice: NewSlice?
        /// Board G1: "Remove {Name} every week?" / "Remove {Name}?" while it is open.
        public var removing: Removing?
        public var haptics = Haptics()
        /// Board G1d: "Save the changes?" before leaving with unsaved drags.
        public var isConfirmingLeave = false
        /// The G1d card's Save: leave once the save has gone through.
        public var leavesAfterSave = false
        /// Where to go after Save in the G1d card: another kid or day, or back.
        public var pendingSwitch: Switch?
        public var saveError: String?
        /// A save is on its way to the store; another Save waits for it.
        public var isSaving = false
        /// The app's calendar, for the time fields' dates (views never read `Calendar.current`).
        public var calendar: Calendar

        public enum Switch: Equatable, Sendable {
            case kid(Kid.ID)
            case day(Day)
            case back
            /// Board G8: the List (or back to the clock); G6: Settings.
            case list(Bool)
            case settings
            /// "Details ›" on an item's or School's slice card (E5 / G2, G4).
            case item(ScheduleItem.ID)
            case school
            /// School's "Remove" on All days: G7 with "At home" picked.
            case atHome
        }

        /// Board G8: the kid's items as a list instead of the clock.
        public var showsList = false
        /// Every item, as the store has it.
        public var items: [ScheduleItem] = []
        public var nowMinute = 0
        /// Spec "No empty slice card": the minute of the slice the home hold began on; the first load
        /// picks the slice there, then it is used up.
        public var heldMinute: Int?

        public var kidInfo: Kid? { kids.first { $0.id == kid } }

        /// Board G8: "Every week" (School first, then activities) and "Just once".
        public var listSections: [ListSection] {
            guard let kid = kidInfo else { return [] }
            var weekly: [ListSection.Row] = []
            if let school = kid.school {
                weekly.append(ListSection.Row(target: .school, picture: "actSchool", title: school.name, // copy-ok: a KitSlot name
                                              detail: L10n.tr("list.detail", DayText.chips(school.days),
                                                              TimeText.hours(school.start, school.end))))
            }
            let rows = { (rows: [ItemRow]) in
                rows.map { ListSection.Row(target: .item($0.id), picture: $0.iconName, title: $0.title,
                                           detail: L10n.tr("list.detail", $0.when, $0.time)) }
            }
            weekly += rows(ItemList.weekly(kid: kid, items: items))
            let once = rows(ItemList.once(kid: kid, items: items, routines: routines, today: today,
                                          nowMinute: nowMinute, calendar: calendar))
            let monthly = rows(ItemList.monthly(kid: kid, items: items))
            return [ListSection(title: L10n.tr("list.every_week"), rows: weekly),
                    ListSection(title: L10n.tr("list.every_month"), rows: monthly),
                    ListSection(title: L10n.tr("list.once"), rows: once)].filter { !$0.rows.isEmpty }
        }

        /// Board G1: Undo and Redo, each on when it has a step to take.
        public var canUndo: Bool { edit.isChanged }
        public var canRedo: Bool { edit.canRedo }

        public init(kid: Kid.ID, today: Day, calendar: Calendar) {
            self.kid = kid
            self.today = today
            self.day = today
            self.fromWhenDate = today
            self.calendar = calendar
        }

        /// The day's template type: Mon–Fri, Sat, or Sun (also on the kid's days off).
        public var dayType: DayType {
            DayPlanner.dayType(on: day, holidays: family.daysOff(kid), calendar: calendar)
        }

        /// Board G1: "Today" (bold) before "Mon 9 Nov" on today; on another day only its date.
        public var dayButtonToday: String? { day == today ? L10n.tr("day.button.today") : nil }
        public var dayButtonDate: String { DayText.short(day, calendar: calendar) }

        /// Board G1c: two weeks of dates from the picker's Monday, under that Monday's month.
        public var pickerDays: [Day] {
            guard let start = pickerStart else { return [] }
            return (0..<14).map { start.adding(days: $0, calendar: calendar) }
        }
        public var pickerMonth: String { pickerStart.map { DayText.monthLong($0.month) } ?? "" }
        /// The picker's header row: the first week's weekdays, "Mon" … "Sun".
        public var pickerWeekdays: [String] {
            pickerDays.prefix(7).map { DayText.shortName($0.weekday(calendar)) }
        }
        /// The picker's two rows of chips (today underlined, the day on the clock picked).
        public var pickerWeeks: [[DayPickerCard.Chip]] {
            let chips = pickerDays.enumerated().map { index, date in
                DayPickerCard.Chip(index: index, day: date.day, isPicked: date == day, isToday: date == today)
            }
            return stride(from: 0, to: chips.count, by: 7).map { Array(chips[$0..<min($0 + 7, chips.count)]) }
        }

        /// Board G1d: the first changed slice as "Dinner 6:30 pm → 7:30 pm, this day" (a template
        /// slice first, else an item).
        public var unsavedLine: String? {
            guard edit.isChanged else { return nil }
            let words = { (scope: Scope) in
                scope == .thisDay ? L10n.tr("day.unsaved.this_day") : L10n.tr("day.unsaved.all_days")
            }
            if let block = edit.firstChange {
                return L10n.tr("day.unsaved.line", block.title, TimeText.withPeriod(block.start),
                               TimeText.withPeriod(block.end), words(edit.changes.first?.scope ?? scope))
            }
            guard let item = edit.firstItemChange else { return nil }
            let scope: Scope = item.isNew ? item.newScope
                : item.isRemoved && item.isRepeating ? .allDays : item.retimeScope ?? .thisDay
            return L10n.tr("day.unsaved.line", item.title, TimeText.withPeriod(item.start),
                           TimeText.withPeriod(item.end), words(scope))
        }

        // MARK: The selected slice

        public var selectedBlock: RoutineBlock? {
            guard case let .block(index)? = selected, edit.blocks.indices.contains(index) else { return nil }
            return edit.blocks[index]
        }
        public var selectedItem: ClockItem? {
            guard case let .item(id)? = selected, let item = edit.item(id), !item.isRemoved else { return nil }
            return item
        }
        /// The card's picture and name.
        public var selectedTitle: String? { selectedBlock?.title ?? selectedItem?.title }
        public var selectedPicture: KitSlot? {
            if let block = selectedBlock { return block.kind == .free ? nil : KitSlot(iconName: block.iconName) }
            return selectedItem.map { KitSlot(iconName: $0.iconName) }
        }
        private var selectedSpan: (start: Int, end: Int)? {
            if let block = selectedBlock { return (block.start, block.end) }
            return selectedItem.map { ($0.start, $0.end) }
        }

        /// The selected slice's start and end as dates for the time fields.
        public var startDate: Date { day.date(minute: selectedSpan?.start ?? 0, calendar: calendar) }
        public var endDate: Date { day.date(minute: selectedSpan?.end ?? 0, calendar: calendar) }
        public var startLabel: String? { selectedSpan.map { TimeText.withPeriod($0.start) } }
        public var endLabel: String? { selectedSpan.map { TimeText.withPeriod($0.end) } }
        /// Board G1: the time field of the knob being dragged is outlined in `pickBlue`: the
        /// selected slice's start when the drag moves its start, its end when it moves its end. An
        /// item's edge moves only the item, never the slice it sits on.
        public var isStartDragged: Bool {
            guard let knob = draggedKnob else { return false }
            switch knob.edge {
            case .blocks: return knob.after == selected
            case let .itemStart(id), let .items(_, id): return selected == .item(id)
            case .itemEnd: return false
            }
        }
        public var isEndDragged: Bool {
            guard let knob = draggedKnob else { return false }
            switch knob.edge {
            case .blocks: return knob.before == selected
            case let .itemEnd(id), let .items(id, _): return selected == .item(id)
            case .itemStart: return false
            }
        }
        private var draggedKnob: DayKnob? { dragging.map { edit.clockKnobs[$0] } }

        /// Board G1g: the selected slice is skipped this day (faded card, no scope tabs, "Bring back").
        public var isSelectedSkipped: Bool { selectedBlock?.isSkipped == true || selectedItem?.isSkipped == true }
        /// A just-once item has one date, so its card has no This day / All days tabs.
        public var showsScopeTabs: Bool { selectedItem.map { $0.isRepeating || $0.isNew } ?? true }
        /// The tab shown: a new item's own scope (its kind), else the screen's.
        public var shownScope: Scope {
            if let slice = newSlice { return edit.item(slice.id)?.newScope ?? slice.scope }
            if let item = selectedItem, item.isNew { return item.newScope }
            return scope
        }
        /// An item placed after another event ("after School") follows it: its times are shown, not edited.
        public var timesAreEditable: Bool { selectedItem?.isAnchored != true }

        /// Spec C6 "One card": "Skip this day" on This day (School too), "Remove" on All days; a
        /// just-once item and a new item only "Remove"; free time and a skipped slice neither.
        public var sliceAction: SliceAction? {
            if let block = selectedBlock {
                guard block.kind != .free, !block.isSkipped else { return nil }
                return scope == .thisDay ? .skip : .remove
            }
            guard let item = selectedItem, !item.isSkipped else { return nil }
            guard item.isRepeating, !item.isNew else { return .remove }
            return scope == .thisDay ? .skip : .remove
        }
        public var sliceActionTitle: String? {
            switch sliceAction {
            case .skip?: strings.tr("day.skip_this_day")
            case .remove?: strings.tr("day.remove")
            case nil: nil
            }
        }

        /// "Details ›" (spec C6 "One card"): items open E5 / G2, School opens G4. A new item has no
        /// form yet.
        public var detailsTitle: String? {
            let opens = selectedItem.map { !$0.isNew } ?? (selectedBlock?.kind == .school && kidInfo?.school != nil)
            // The "›" is drawn by GlyphText at the key's "%@" (Playpen Sans has none).
            return opens ? strings.tr("day.details", "%@") : nil
        }

        /// Board G1: the ConfirmCard's words while it is open.
        public var removeTitle: String? {
            switch removing {
            case let .series(id)?:
                edit.item(id)?.isMonthly == true ? strings.tr("day.remove.monthly", title(of: .item(id)))
                    : strings.tr("day.remove.series", title(of: .item(id)))
            case let .once(id)?: strings.tr("day.remove.once", title(of: .item(id)))
            case nil: nil
            }
        }
        public var removeAccept: String { strings.tr("day.remove.accept") }
        public var removeKeep: String { strings.tr("day.remove.keep") }

        func title(of source: ClockSlice.Source) -> String {
            switch source {
            case let .block(index): edit.blocks.indices.contains(index) ? edit.blocks[index].title : ""
            case let .item(id): edit.item(id)?.title ?? ""
            }
        }

        // MARK: Saving

        /// The day type's template the clock's day would have without its own one: where an All days
        /// change goes.
        var baseBlocks: [RoutineBlock] {
            DayPlanner.template(for: kid, on: day, routines: shownRoutines.filter { $0.onlyOn == nil },
                                holidays: family.daysOff(kid), calendar: calendar)?.blocks ?? []
        }

        /// The templates as each date reads them: a waiting School change from its day on (#255).
        var shownRoutines: [Routine] { kidInfo?.readingWaitingHours(routines) ?? routines }

        /// What Save writes for the template, each change by its own scope: the All days changes on
        /// the day type's template from G5's date (never before today), and, when there are This day
        /// changes, the day's own template (with the All days changes too when they start by then).
        public var routinesToSave: [Routine] {
            // A School save from today reaches the later templates that follow the old record first.
            var routines = followingToSave
            let base = baseBlocks
            let series = edit.seriesBlocks(from: base)
            // Templates from a waiting change's day on keep today's School (#255: never a copy).
            let kid = schoolToSave ?? kidInfo
            let stored = DayPlanner.template(for: self.kid, on: day, routines: self.routines.filter { $0.onlyOn == nil },
                                             holidays: family.daysOff(self.kid), calendar: calendar)?.blocks ?? []
            if series != base {
                let blocks = kid?.storingSchool(series, on: allDaysFrom, stored: stored) ?? series
                routines.append(Routine(kid: self.kid, dayType: dayType, from: allDaysFrom, blocks: blocks))
            }
            if edit.hasThisDayTemplateChange {
                // All days changes reach this day only when G5's date is on or before it.
                let edited = allDaysFrom <= day ? edit.blocks : edit.replaying(on: edit.savedBlocks, scopes: [.thisDay])
                let blocks = kid?.storingSchool(edited, on: day, stored: stored) ?? edited
                routines.append(Routine.day(day, kid: self.kid, dayType: dayType, blocks: blocks))
            }
            return routines
        }

        /// A School move saved from today (the record changes now): the later templates, a day's own
        /// ones included, whose School follows the old record move with it.
        var followingToSave: [Routine] {
            guard allDaysFrom <= today, let kid = schoolToSave, let old = kidInfo?.school, kid.school != old else { return [] }
            return kid.followingSchool(routines, from: today, old: old)
        }

        /// G5 asks from when only when there are All days changes; its date applies only to them.
        public var needsFromWhen: Bool { edit.hasAllDaysChange }

        /// Board G5's tabs: "Today", the next day of this day's type ("Tomorrow" or "Sat 14 Nov"; none
        /// within 14 days hides it), "Date".
        public var fromWhenTabs: [(ItemEditorFeature.FromWhen, String)] {
            FromWhenTabs.tabs(next: nextOfType, today: today, calendar: calendar)
        }

        /// The first day after today, within 14 days, that uses this day's template type.
        var nextOfType: Day? {
            FromWhenTabs.nextDay(after: today, calendar: calendar) {
                DayPlanner.dayType(on: $0, holidays: family.daysOff(kid), calendar: calendar) == dayType
            }
        }

        /// The day "Details ›" opens G2 on (its G5 starts there): the clock's day; none from the List.
        public var editorDay: Day? { showsList ? nil : day }

        /// Where an All days template starts: G5's choice, never before today.
        public var allDaysFrom: Day {
            switch fromWhen {
            case .next?: nextOfType ?? today
            case .date?: max(fromWhenDate, today)
            case .today?, nil: today
            }
        }
        public var fromWhenDateLabel: String { DayText.dayMonth(max(fromWhenDate, today), calendar: calendar) }
        public var fromWhenDateValue: Date { max(fromWhenDate, today).date(calendar: calendar) }

        // MARK: The clock

        public var sectors: [ClockSector] {
            edit.slices.map { slice in
                ClockSector(start: slice.start, end: slice.end,
                            style: ClockSlotStyle(rawValue: slice.kind.rawValue) ?? .play,
                            iconName: slice.kind == .free || slice.iconName.isEmpty ? nil : slice.iconName,
                            isCurrent: slice.source == selected, showsStar: false, priority: slice.priority,
                            isFaded: slice.isSkipped)
            }
        }

        public var knobs: [EditClock.Knob] {
            edit.clockKnobs.map { EditClock.Knob(minute: $0.minute, isLocked: false) }
        }

        /// The knob being dragged, by its place among the knobs now.
        public var dragging: Int? {
            guard let drag else { return nil }
            return edit.clockKnobs.firstIndex { $0.edge == drag.edge }
        }

        /// Spec "Add between two slices": a "+" on every shared knob, an item's edges too, all the
        /// time; "+" that would touch take the outermost free ring (`EditClock.placed`); the knob
        /// being dragged hides its "+" without moving the others to another ring.
        public var addButtons: [EditClock.AddBetween] {
            let dragging = dragging
            return EditClock.placed(edit.clockKnobs.enumerated().compactMap { index, knob in
                knob.showsAdd ? EditClock.AddBetween(knob: index, minute: knob.minute) : nil
            })
            .filter { $0.knob != dragging }
        }

        /// While dragging: "Dinner ends" / "7:30 pm" / "Shower starts"; else the selected slice's name.
        public var hub: EditClock.Hub {
            if let dragging {
                let knob = edit.clockKnobs[dragging]
                return EditClock.Hub(above: L10n.tr("day.knob.ends", title(of: knob.before)),
                                     time: TimeText.withPeriod(knob.minute),
                                     below: L10n.tr("day.knob.starts", title(of: knob.after)))
            }
            // Board G1f: a new item reads "New" / "7:30 pm" / "until 8:00 pm".
            if let slice = newSlice {
                let span = edit.item(slice.id).map { ($0.start, $0.end) } ?? (slice.start, slice.end)
                return EditClock.Hub(above: L10n.tr("day.new.hub"), time: TimeText.withPeriod(span.0),
                                     below: L10n.tr("home.hub.until", TimeText.withPeriod(span.1)))
            }
            // Board G1g: "Play" / "Skipped" / "this day".
            if isSelectedSkipped, let title = selectedTitle {
                return EditClock.Hub(above: title, time: L10n.tr("day.skipped.hub"),
                                     below: L10n.tr("day.skipped.this_day"), timeIsMuted: true)
            }
            return EditClock.Hub(title: selectedTitle)
        }

        /// The drawn slice at `minute`: the one starting there, else the one around it.
        func slice(at minute: Int) -> ClockSlice? {
            let slices = edit.slices
            return slices.first { $0.start == minute } ?? slices.first { $0.start <= minute && minute < $0.end }
        }

        /// What an All days change does to the school record (layout v37): the School slice's new
        /// times become School's hours, from today at once, from a later day as the waiting hours change
        /// (spec G5 "What Settings shows meanwhile"). nil when School did not move on All days. "Remove
        /// School every week" changes only the template, never the school record.
        public var schoolToSave: Kid? {
            let base = baseBlocks
            // The record that applies from G5's day: a waiting change keeps its days, Bring and the rest.
            guard edit.hasAllDaysChange, let kid = kidInfo,
                  let school = kid.waitingHours(on: allDaysFrom)?.school ?? kid.school,
                  let block = edit.seriesBlocks(from: base).first(where: { $0.kind == .school }),
                  let was = base.first(where: { $0.kind == .school }),
                  block.start != was.start || block.end != was.end else { return nil }
            return kid.savingSchool(school.moved(sliceStart: block.start, sliceEnd: block.end), from: allDaysFrom,
                                    today: today)
        }

        /// Board G1f: seven day pictures and "More" (two rows of four), the picked one first.
        public var newSlicePictures: [KitSlot] {
            let picked = newSlice?.iconName.flatMap(KitSlot.init(rawValue:))
            let rest = OurDayFeature.suggested.filter { $0 != picked }
            return Array(([picked].compactMap { $0 } + rest).prefix(7))
        }
    }

    /// What a save wrote, for the screen's copy of the store.
    public struct Saved: Equatable, Sendable {
        public var routines: [Routine]
        public var items: [ScheduleItem]
        public var deleted: [ScheduleItem.ID]
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case task
        case loaded(ScheduleSnapshot?, family: FamilyCalendar)
        case kidTabTapped(Kid.ID)
        /// Board G1c: the day button opens the picker; ‹ › page two weeks; a date or "Today" picks.
        case dayButtonTapped
        case pickerPageTapped(Int)
        case pickerDayTapped(Day)
        /// A chip by its place in the picker's two weeks.
        case pickerChipTapped(Int)
        case pickerTodayTapped
        case pickerClosed
        case scopeTapped(Scope)
        /// Board G5 on an All days save: the choice, its date, Save and Cancel.
        case fromWhenPicked(ItemEditorFeature.FromWhen)
        case fromWhenDatePicked(Date)
        case fromWhenSaveTapped
        case fromWhenCancelTapped
        case knobDragged(index: Int, minute: Int)
        case knobReleased(Int)
        /// Board G1: the "+" on a shared knob (by the knob's place) adds an item there.
        case addBetweenTapped(Int)
        case sliceTapped(start: Int)
        case plusTapped(start: Int)
        case startPicked(Date)
        case endPicked(Date)
        /// The card's "Skip this day" or "Remove".
        case sliceActionTapped
        case removeConfirmed
        case removeCancelled
        /// Board G1g: bring a skipped slice back.
        case bringBackTapped
        /// "Details ›": the item's form (E5 / G2) or School's (G4).
        case detailsTapped
        /// Board G1f: a picture puts the item on the clock (named after it); the name and times edit it.
        case newSlicePicturePicked(String)
        case newSliceNameChanged(String)
        case newSliceMoreTapped
        case undoTapped
        case redoTapped
        /// Board G1 header: List (a toggle) and Settings.
        case listTapped
        case settingsTapped
        /// Board G8: a row (School or an item) and the side column's adds.
        case listRowTapped(ListSection.Target)
        /// Board G8: one "Add"; the form opens on Every week and its Repeat tabs pick the kind.
        case addTapped
        case saveTapped
        case saved(Result<Saved, SaveError>)
        case backTapped
        /// Board G1d: Save or Cancel.
        case unsavedSaveTapped
        case leaveCancelled
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// "←": the app leaves grown-up mode.
            case finished
            case openSettings(Kid.ID)
            case openItem(ScheduleItem.ID)
            case add(Kid.ID, ItemForm.Repeat)
            /// Board G8: the School row opens G4.
            case openSchool
            /// School's "Remove" on All days (spec C6 "One card"): G7 with "At home" picked, so where
            /// the kid goes changes the one way it always does.
            case removeSchool(Kid.ID)
        }
    }

    public struct SaveError: Error, Equatable {}

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.holidays) var holidays
    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                state.nowMinute = Day.minute(of: date.now, calendar: calendar)
                let year = state.today.year
                return .run { [scheduleStore, schoolDirectory, holidays] send in
                    let snapshot = try? await scheduleStore.load()
                    // G1c pages into next year, so its public holidays count too.
                    let days = await holidays.holidays(year).map(\.day) + holidays.holidays(year + 1).map(\.day)
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: days)
                    await send(.loaded(snapshot, family: family))
                }

            case let .loaded(snapshot, family):
                state.kids = snapshot?.kids ?? []
                state.routines = snapshot?.routines ?? []
                state.items = snapshot?.items ?? []
                state.family = family
                loadTemplate(&state)
                return .none

            case let .kidTabTapped(kid):
                guard kid != state.kid else { return .none }
                return ask(.kid(kid), &state)

            case .dayButtonTapped:
                if state.pickerStart != nil {
                    state.pickerStart = nil
                } else {
                    // The picker opens on the week of the day on the clock (Monday first).
                    state.pickerStart = state.day.mondayOfWeek(calendar: calendar)
                }
                return .none

            case let .pickerPageTapped(step):
                state.pickerStart = state.pickerStart?.adding(days: 14 * step, calendar: calendar)
                return .none

            case let .pickerDayTapped(day):
                return pick(day, &state)

            case let .pickerChipTapped(index):
                guard state.pickerDays.indices.contains(index) else { return .none }
                return pick(state.pickerDays[index], &state)

            case .pickerTodayTapped:
                state.pickerStart = nil
                guard state.day != state.today else { return .none }
                return ask(.day(state.today), &state)

            case .pickerClosed:
                state.pickerStart = nil
                return .none

            case let .scopeTapped(scope):
                // Spec "Tapping +": a new item's tabs pick its kind, just once (This day) or every
                // week (All days), as one change; the new card's tabs act on that card only.
                if var slice = state.newSlice {
                    slice.scope = scope
                    state.newSlice = slice
                    if slice.isOnClock { state.edit.setNewItemScope(slice.id, scope) }
                } else if let item = state.selectedItem, item.isNew {
                    state.edit.setNewItemScope(item.id, scope)
                } else {
                    state.scope = scope
                }
                return .none

            case let .fromWhenPicked(choice):
                state.fromWhen = choice
                return .none

            case let .fromWhenDatePicked(date):
                state.fromWhen = .date
                state.fromWhenDate = max(Day(date, calendar: calendar), state.today)
                return .none

            case .fromWhenCancelTapped:
                state.fromWhen = nil
                state.leavesAfterSave = false
                state.pendingSwitch = nil
                return .none

            case .fromWhenSaveTapped:
                guard !state.isSaving else { return .none }
                return save(&state)

            case let .knobDragged(index, minute):
                if state.drag == nil {
                    let knobs = state.edit.clockKnobs
                    guard knobs.indices.contains(index) else { return .none }
                    let knob = knobs[index]
                    state.newSlice = nil
                    state.drag = Drag(edge: knob.edge, range: state.edit.range(of: knob.edge), from: knob.minute)
                    state.dragOrigin = knob.minute
                    state.edit.beginChange()
                }
                // The drag keeps its knob even when the knobs around it change.
                guard let drag = state.drag else { return .none }
                let before = state.edit.clockKnobs.first { $0.edge == drag.edge }?.minute ?? minute
                let move = state.edit.move(drag.edge, to: minute, within: drag.range)
                feel(move, from: before, &state)
                return .none

            case .knobReleased:
                guard let drag = state.drag else { return .none }
                state.drag = nil
                state.dragOrigin = nil
                state.edit.retimed(drag.edge, scope: state.scope)
                switch drag.edge {
                case let .blocks(before):
                    // Free time left under 15 minutes joins the slice moved on purpose ("No forced gaps").
                    state.selected = state.edit.finishMove(before: before, from: drag.from, scope: state.scope)
                        .map(ClockSlice.Source.block)
                case let .itemStart(id), let .itemEnd(id):
                    state.edit.settleItem(id)
                    state.selected = .item(id)
                case let .items(ending, starting):
                    state.edit.settleItem(ending)
                    state.edit.settleItem(starting)
                    state.selected = .item(ending)
                }
                return .none

            case let .addBetweenTapped(index):
                state.message = nil
                guard let span = state.edit.addSpan(atKnob: index) else {
                    state.message = L10n.tr("day.add_between.no_room")
                    return .none
                }
                state.newSlice = NewSlice(id: uuid(), start: span.lowerBound, end: span.upperBound, scope: state.scope)
                return .none

            case let .sliceTapped(start):
                state.selected = state.slice(at: start)?.source
                state.newSlice = nil
                state.message = nil
                return .none

            case let .plusTapped(start):
                guard let span = state.edit.addSpan(inFreeAt: start) else { return .none }
                state.selected = state.slice(at: span.lowerBound)?.source
                state.message = nil
                state.newSlice = NewSlice(id: uuid(), start: span.lowerBound, end: span.upperBound, scope: state.scope)
                return .none

            case let .startPicked(date):
                let minute = Day.minute(of: date, calendar: calendar)
                switch state.selected {
                case let .block(block)?:
                    let before = state.edit.blocks[block].start
                    feel(state.edit.setStart(ofBlock: block, to: minute, scope: state.scope), from: before, &state)
                case let .item(id)?:
                    guard let before = state.edit.item(id)?.start else { return .none }
                    feel(state.edit.setItemStart(id, to: minute, scope: state.scope), from: before, &state)
                case nil:
                    break
                }
                return .none

            case let .endPicked(date):
                let minute = Day.minute(of: date, calendar: calendar)
                switch state.selected {
                case let .block(block)?:
                    let before = state.edit.blocks[block].end
                    feel(state.edit.setEnd(ofBlock: block, to: minute, scope: state.scope), from: before, &state)
                case let .item(id)?:
                    guard let before = state.edit.item(id)?.end else { return .none }
                    feel(state.edit.setItemEnd(id, to: minute, scope: state.scope), from: before, &state)
                case nil:
                    break
                }
                return .none

            case .sliceActionTapped:
                guard let action = state.sliceAction, let source = state.selected else { return .none }
                switch (action, source) {
                case let (.skip, .block(block)):
                    state.edit.setSkipped(block, true)
                case let (.skip, .item(id)):
                    state.edit.setItemSkipped(id, true)
                case let (.remove, .block(block)):
                    // School opens G7 with At home picked (after G1d when something is unsaved); a
                    // day slice becomes free time.
                    if state.edit.blocks[block].kind == .school {
                        return ask(.atHome, &state)
                    } else {
                        state.selected = .block(state.edit.makeFree(block, scope: .allDays))
                    }
                case let (.remove, .item(id)):
                    guard let item = state.edit.item(id) else { return .none }
                    if item.isNew {
                        remove(item, &state)
                    } else {
                        state.removing = item.isRepeating ? .series(id) : .once(id)
                    }
                }
                return .none

            case .removeConfirmed:
                guard let removing = state.removing else { return .none }
                state.removing = nil
                switch removing {
                case let .series(id), let .once(id):
                    if let item = state.edit.item(id) { remove(item, &state) }
                }
                return .none

            case .removeCancelled:
                state.removing = nil
                return .none

            case .bringBackTapped:
                switch state.selected {
                case let .block(block)?: state.edit.setSkipped(block, false)
                case let .item(id)?: state.edit.setItemSkipped(id, false)
                case nil: break
                }
                return .none

            case .detailsTapped:
                guard state.detailsTitle != nil else { return .none }
                switch state.selected {
                case let .item(id)?: return ask(.item(id), &state)
                case .block?: return ask(.school, &state)
                case nil: return .none
                }

            case let .newSlicePicturePicked(name):
                guard var slice = state.newSlice else { return .none }
                let title = slice.nameIsTyped ? slice.name : String(ItemForm.label(for: name).prefix(Self.longestName))
                if slice.isOnClock {
                    state.edit.restyleItem(slice.id, title: title, iconName: name)
                } else {
                    state.edit.add(ClockItem(id: slice.id, title: title, iconName: name, start: slice.start,
                                             end: slice.end, isRepeating: slice.scope == .allDays, isNew: true))
                    slice.isOnClock = true
                }
                slice.iconName = name
                slice.name = title
                slice.isPickingMore = false
                state.newSlice = slice
                state.selected = .item(slice.id)
                return .none

            case let .newSliceNameChanged(text):
                guard var slice = state.newSlice else { return .none }
                slice.name = String(text.prefix(Self.longestName))
                slice.nameIsTyped = true
                if slice.isOnClock, let icon = slice.iconName {
                    let trimmed = slice.name.trimmingCharacters(in: .whitespaces)
                    state.edit.restyleItem(slice.id, title: trimmed.isEmpty ? ItemForm.label(for: icon) : trimmed,
                                           iconName: icon)
                }
                state.newSlice = slice
                return .none

            case .newSliceMoreTapped:
                state.newSlice?.isPickingMore.toggle()
                return .none

            case .undoTapped:
                let minute = state.slice(of: state.selected)?.start
                state.edit.undo()
                // Board G1f: Undo that takes a new item back closes its card; one that takes back a
                // later step (a typed time, its tab) keeps the card with the item.
                if let slice = state.newSlice, slice.isOnClock, state.edit.item(slice.id) == nil { state.newSlice = nil }
                state.message = nil
                keepSelection(near: minute, &state)
                return .none

            case .redoTapped:
                let minute = state.slice(of: state.selected)?.start
                state.edit.redo()
                state.message = nil
                keepSelection(near: minute, &state)
                return .none

            case .listTapped:
                return ask(.list(!state.showsList), &state)

            case .settingsTapped:
                return ask(.settings, &state)

            case let .listRowTapped(target):
                switch target {
                case .school: return .send(.delegate(.openSchool))
                case let .item(id): return .send(.delegate(.openItem(id)))
                }

            case .addTapped:
                return .send(.delegate(.add(state.kid, .weekly)))

            case .saveTapped:
                guard !state.isSaving else { return .none }
                // Spec "Edit scope": All days changes ask from when first (board G5).
                if state.needsFromWhen, state.fromWhen == nil {
                    // Spec G5: it opens on the day on the clock (never before today).
                    let opening = FromWhenTabs.opening(shown: state.day, next: state.nextOfType, today: state.today)
                    state.fromWhen = opening.choice
                    state.fromWhenDate = opening.date
                    return .none
                }
                return save(&state)

            case let .saved(.success(saved)):
                state.isSaving = false
                for routine in saved.routines {
                    state.routines.removeAll {
                        $0.kid == routine.kid && $0.dayType == routine.dayType && $0.from == routine.from
                            && $0.onlyOn == routine.onlyOn
                    }
                    state.routines.append(routine)
                }
                let written = Set(saved.items.map(\.id) + saved.deleted)
                state.items = state.items.filter { !written.contains($0.id) } + saved.items
                // The clock shows the day as saved (its template and items by the store's rules):
                // nothing to undo or redo.
                let minute = state.slice(of: state.selected)?.start
                state.edit = TemplateEdit(blocks: template(state)?.blocks ?? [], items: clockItems(state))
                keepSelection(near: minute, &state)
                state.newSlice = nil
                state.saveError = nil
                // Grown-up mode stays on the clock after a save (board G1), unless G1d's Save asked to leave.
                guard state.leavesAfterSave else { return .none }
                state.leavesAfterSave = false
                var next = state.pendingSwitch
                state.pendingSwitch = nil
                // "Details": a series split from today on is a new item; open the one on the clock.
                if case .item? = next, case let .item(id)? = state.selected { next = .item(id) }
                return go(next, &state)

            case .saved(.failure):
                state.isSaving = false
                state.saveError = L10n.tr("day.save_failed")
                state.leavesAfterSave = false
                state.pendingSwitch = nil
                return .none

            case .backTapped:
                return ask(.back, &state)

            case .unsavedSaveTapped:
                state.isConfirmingLeave = false
                state.leavesAfterSave = true
                return .send(.saveTapped)

            case .leaveCancelled:
                state.isConfirmingLeave = false
                state.pendingSwitch = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Board G1c: a picked day closes the picker and, after G1d if needed, shows on the clock.
    private func pick(_ day: Day, _ state: inout State) -> Effect<Action> {
        state.pickerStart = nil
        guard day != state.day else { return .none }
        return ask(.day(day), &state)
    }

    /// Writes each change by its own scope (`routinesToSave`, `ClockSave`); the G5 card closes.
    private func save(_ state: inout State) -> Effect<Action> {
        let routines = state.routinesToSave
        let kid = state.schoolToSave
        let writes = ClockSave.writes(items: state.edit.items, saved: state.edit.savedItems, originals: state.items,
                                      kid: state.kid, day: state.day, from: state.allDaysFrom, calendar: calendar,
                                      newID: { uuid() })
        if let kid { state.kids = state.kids.map { $0.id == kid.id ? kid : $0 } }
        state.fromWhen = nil
        state.isSaving = true
        return .run { [scheduleStore] send in
            do {
                for routine in routines { try await scheduleStore.saveRoutine(routine) }
                if !writes.saved.isEmpty { try await scheduleStore.saveAll(writes.saved) }
                for id in writes.deleted { try await scheduleStore.delete(id) }
                // Layout v37: School's hours follow the slice (Arrive by, Latest's grace, the end).
                if let kid { try await scheduleStore.saveKid(kid) }
                await send(.saved(.success(Saved(routines: routines, items: writes.saved, deleted: writes.deleted))))
            } catch {
                await send(.saved(.failure(SaveError())))
            }
        }
    }

    /// The day's template: its own one, else the day type's.
    private func template(_ state: State) -> Routine? {
        DayPlanner.template(for: state.kid, on: state.day, routines: state.shownRoutines,
                            holidays: state.family.daysOff(state.kid), calendar: calendar)
    }

    /// The kid's items on the day on the clock.
    private func clockItems(_ state: State) -> [ClockItem] {
        DayPlanner.clockItems(on: state.day, kid: state.kid, routines: state.shownRoutines, items: state.items,
                              holidays: state.family.daysOff(state.kid), calendar: calendar)
    }

    /// The day on the clock: its template (the day's own one, else the day type's) and its items.
    private func loadTemplate(_ state: inout State) {
        state.edit = TemplateEdit(blocks: template(state)?.blocks ?? [], items: clockItems(state))
        state.scope = .thisDay
        // Spec "G1 as built": the card is never empty: the slice the hold began on, the slice now on
        // today, else the day's first.
        let now = state.heldMinute ?? (state.day == state.today ? state.nowMinute : nil)
        state.heldMinute = nil
        state.selected = (now.flatMap { minute in state.edit.slices.first { $0.start <= minute && minute < $0.end } }
            ?? state.edit.slices.first)?.source
        state.drag = nil
        state.dragOrigin = nil
        state.newSlice = nil
        state.removing = nil
        state.message = nil
    }

    /// An item off the clock (a new one goes at once); the slice underneath is picked.
    private func remove(_ item: ClockItem, _ state: inout State) {
        state.edit.removeItem(item.id)
        state.selected = state.slice(at: item.start)?.source
    }

    /// After Undo, Redo or Save: the picked slice stays picked while it is on the clock, else the
    /// slice now at its old start.
    private func keepSelection(near minute: Int?, _ state: inout State) {
        guard state.slice(of: state.selected) == nil else { return }
        state.selected = (minute.flatMap { state.slice(at: $0) } ?? state.edit.slices.first)?.source
    }

    /// Unsaved changes ask "Save the changes?" first (board G1d).
    private func ask(_ next: State.Switch, _ state: inout State) -> Effect<Action> {
        guard state.edit.isChanged else { return go(next, &state) }
        state.pendingSwitch = next
        state.isConfirmingLeave = true
        return .none
    }

    private func go(_ next: State.Switch?, _ state: inout State) -> Effect<Action> {
        switch next {
        case let .kid(kid):
            state.kid = kid
            loadTemplate(&state)
            return .none
        case let .day(day):
            state.day = day
            loadTemplate(&state)
            return .none
        case .back:
            return .send(.delegate(.finished))
        case let .list(shows):
            loadTemplate(&state)
            state.showsList = shows
            return .none
        case .settings:
            loadTemplate(&state)
            return .send(.delegate(.openSettings(state.kid)))
        case let .item(id):
            return .send(.delegate(.openItem(id)))
        case .school:
            return .send(.delegate(.openSchool))
        case .atHome:
            return .send(.delegate(.removeSchool(state.kid)))
        case nil:
            return .none
        }
    }

    /// A light tap per 5-minute step, a stronger one on the hour, a bump at a limit.
    private func feel(_ move: TemplateEdit.Move, from before: Int, _ state: inout State) {
        switch move {
        case let .moved(minute) where minute != before:
            if minute % 60 == 0 { state.haptics.hours += 1 } else { state.haptics.steps += 1 }
        case .stopped:
            state.haptics.bumps += 1
        default:
            break
        }
    }
}

extension OurDayFeature.State {
    /// The first drawn piece of a slice, or nil when it is no longer on the clock.
    func slice(of source: ClockSlice.Source?) -> ClockSlice? {
        guard let source else { return nil }
        return edit.slices.first { $0.source == source }
    }
}

/// Board G8: a titled block of the List.
public struct ListSection: Equatable, Sendable {
    public enum Target: Hashable, Sendable {
        case school
        case item(ScheduleItem.ID)
    }

    public struct Row: Equatable, Identifiable, Sendable {
        public var target: Target
        /// A `KitSlot` raw value.
        public var picture: String
        public var title: String
        /// "Mon · Wed · 3:30–4:30 pm", "Sat 14 Nov · 2:00–4:00 pm".
        public var detail: String
        public var id: Target { target }
    }

    public var title: String
    public var rows: [Row]
}
