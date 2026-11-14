import ComposableArchitecture
import DesignSystem
import Domain
import KitArt
import Foundation
import HolidayProvider
import ScheduleStore
import SchoolDirectory
import Strings

/// G1 · The day on the clock (spec "G1"): a grown-up drags the times of a kid's day on a real date.
/// The rules live in `TemplateEdit`; this reducer keeps the screen's state and saves the day's
/// template for this day only or for all days from it (spec "Edit scope").
@Reducer
public struct OurDayFeature {
    /// A new slice being filled in over a free span ("+").
    /// Every picture a day slice can have (user, 2026-11-09: all of them, sleep too), in day order.
    public static let pictures: [KitSlot] = [
        .actSleep, .pyjamas, .teddy, .sun, .toilet, .toothbrush, .washFace, .hairBrush, .shirt, .actBreakfast,
        .milk, .backpack, .shoe, .actSchool, .homework, .actPlay, .blocks, .playground, .snack, .tv, .actStory,
        .actCCA, .actArt, .actMusic, .actPiano, .actDance, .actFootball, .actSwim, .actLanguageSchool, .actChurch,
        .actDinner, .actShower, .cake, .doctor,
    ]

    /// The slice kind a picture gives (its colour on the clock and the night look's sleep): the
    /// sleep pictures make sleep, dinner makes dinner, and so on; anything else is play.
    public static func kind(forPicture name: String) -> SlotKind {
        switch KitSlot(rawValue: name) {
        case .actSleep?, .pyjamas?, .teddy?: .sleep
        case .sun?, .toilet?, .toothbrush?, .washFace?, .hairBrush?, .shirt?, .actBreakfast?, .milk?, .backpack?,
             .shoe?: .morning
        case .actSchool?, .homework?: .school
        case .actCCA?, .actArt?, .actMusic?, .actPiano?, .actDance?, .actFootball?, .actSwim?, .actLanguageSchool?,
             .actChurch?: .afterSchool
        case .actDinner?: .dinner
        case .actShower?: .evening
        case .cake?, .doctor?: .event
        default: .play
        }
    }

    /// Board G1f (layout v41): the seven pictures a new slice offers before "More".
    public static let suggested: [KitSlot] = [.actPlay, .snack, .actStory, .homework, .tv, .actArt, .actMusic]
    /// Slice names keep the C5 limit (14 characters).
    static let longestName = 14

    public struct NewSlice: Equatable, Sendable {
        public var block: Int
        public var name: String
        public var iconName: String?
        /// Board G1e: the slice was put between two others; closing the card without adding takes it back.
        public var isBetween: Bool
        /// Board G1f: a picture was picked, so the slice is on the clock (Undo takes it back).
        public var isOnClock = false
        /// The grown-up typed a name; a later picture no longer renames the slice.
        public var nameIsTyped = false
        /// "More" shows every day picture.
        public var isPickingMore = false

        public init(block: Int, name: String = "", iconName: String? = nil, isBetween: Bool = false) {
            self.block = block
            self.name = name
            self.iconName = iconName
            self.isBetween = isBetween
        }
    }

    /// Haptic moments for the view (board C6): a 5-minute step, a step onto the hour, a stop at a limit.
    public struct Haptics: Equatable, Sendable {
        public var steps = 0
        public var hours = 0
        public var bumps = 0
    }

    /// "This day" or "All days" (spec "Edit scope"): a drag changes this day unless All days is picked.
    public enum Scope: Hashable, Sendable { case thisDay, allDays }

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        /// The date on the clock (board G1's day button).
        public var day: Day
        public var saveScope: Scope = .thisDay
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
        public var selected: Int?
        public var dragging: Int?
        public var dragOrigin: Int?
        public var message: String?
        public var newSlice: NewSlice?
        /// Board G1e: the knob whose "+" is showing after a tap on it.
        public var addBetween: Int?
        public var haptics = Haptics()
        /// Board G1d: "Save the changes?" before leaving with unsaved drags.
        public var isConfirmingLeave = false
        /// The G1d card's Save: leave once the save has gone through.
        public var leavesAfterSave = false
        /// Where to go after Save in the G1d card: another kid or day, or back.
        public var pendingSwitch: Switch?
        public var saveError: String?
        /// The app's calendar, for the time fields' dates (views never read `Calendar.current`).
        public var calendar: Calendar

        public enum Switch: Equatable, Sendable {
            case kid(Kid.ID)
            case day(Day)
            case back
            /// Board G8: the List (or back to the clock); G6: Settings.
            case list(Bool)
            case settings
        }

        /// Board G8: the kid's items as a list instead of the clock.
        public var showsList = false
        /// Every item, for the List.
        public var items: [ScheduleItem] = []
        public var nowMinute = 0
        /// Spec "No empty slice card": the minute of the slice the home hold began on; the first load
        /// picks the template slice there, then it is used up.
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
        /// The picker's two rows of chips (today underlined, the day on the clock picked).
        public var pickerWeeks: [[DayPickerCard.Chip]] {
            let chips = pickerDays.enumerated().map { index, date in
                DayPickerCard.Chip(index: index, weekday: DayText.shortName(date.weekday(calendar)), day: date.day,
                                   isPicked: date == day, isToday: date == today)
            }
            return stride(from: 0, to: chips.count, by: 7).map { Array(chips[$0..<min($0 + 7, chips.count)]) }
        }

        /// Board G1d: the first changed slice as "Dinner 6:30 pm → 7:30 pm, this day".
        public var unsavedLine: String? {
            guard edit.isChanged, let block = edit.firstChange else { return nil }
            return L10n.tr("day.unsaved.line", block.title, TimeText.withPeriod(block.start), TimeText.withPeriod(block.end),
                           saveScope == .thisDay ? L10n.tr("day.unsaved.this_day") : L10n.tr("day.unsaved.all_days"))
        }

        /// The selected slice's start and end as dates for the time fields.
        public var startDate: Date { day.date(minute: selectedBlock?.start ?? 0, calendar: calendar) }
        public var endDate: Date { day.date(minute: selectedBlock?.end ?? 0, calendar: calendar) }

        /// What Save writes: this day's own template, or the day type's template from G5's choice
        /// (never from before today).
        public var routineToSave: Routine {
            switch saveScope {
            case .thisDay:
                Routine.day(day, kid: kid, dayType: dayType, blocks: edit.blocks)
            case .allDays:
                Routine(kid: kid, dayType: dayType, from: allDaysFrom, blocks: edit.blocks)
            }
        }

        /// Board G5's tabs: "Today", "Next Sat" (the next day of this day's type), "Date".
        public var fromWhenTabs: [(ItemEditorFeature.FromWhen, String)] {
            [(.today, L10n.tr("from_when.today")),
             (.next, L10n.tr("from_when.next", nextOfType.map { DayText.shortName($0.weekday(calendar)) } ?? "")),
             (.date, L10n.tr("from_when.date"))]
        }

        /// The first day after today that uses this day's template type.
        var nextOfType: Day? {
            (1...14).map { today.adding(days: $0, calendar: calendar) }.first {
                DayPlanner.dayType(on: $0, holidays: family.daysOff(kid), calendar: calendar) == dayType
            }
        }

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

        public var sectors: [ClockSector] {
            edit.blocks.enumerated().map { index, block in
                ClockSector(start: block.start, end: block.end,
                            style: ClockSlotStyle(rawValue: block.kind.rawValue) ?? .play,
                            iconName: block.kind == .free || block.iconName.isEmpty ? nil : block.iconName,
                            isCurrent: index == selected, showsStar: false, priority: 0)
            }
        }

        public var knobs: [EditClock.Knob] {
            edit.knobs.map { knob in
                EditClock.Knob(minute: knob.minute, isLocked: false,
                               label: L10n.tr("day.knob.label", edit.blocks[knob.before].title,
                                              TimeText.withPeriod(knob.minute)))
            }
        }

        /// While dragging: "Dinner ends" / "7:30 pm" / "Shower starts"; else the selected slice's name.
        public var hub: EditClock.Hub {
            if let dragging, edit.knobs.indices.contains(dragging) {
                let knob = edit.knobs[dragging]
                return EditClock.Hub(above: L10n.tr("day.knob.ends", edit.blocks[knob.before].title),
                                     time: TimeText.withPeriod(knob.minute),
                                     below: L10n.tr("day.knob.starts", edit.blocks[knob.after].title))
            }
            // Board G1f: a new slice on the clock reads "New" / "7:30 pm" / "until 8:00 pm".
            if let slice = newSlice, slice.isOnClock, edit.blocks.indices.contains(slice.block) {
                let block = edit.blocks[slice.block]
                return EditClock.Hub(above: L10n.tr("day.new.hub"), time: TimeText.withPeriod(block.start),
                                     below: L10n.tr("home.hub.until", TimeText.withPeriod(block.end)))
            }
            return EditClock.Hub(title: selected.map { edit.blocks[$0].title })
        }

        public var selectedBlock: RoutineBlock? { selected.map { edit.blocks[$0] } }
        public var startLabel: String? { selectedBlock.map { TimeText.withPeriod($0.start) } }
        public var endLabel: String? { selectedBlock.map { TimeText.withPeriod($0.end) } }
        public var canMakeFree: Bool { selectedBlock.map { !$0.isLocked && $0.kind != .free } ?? false }

        /// Board G1e: the "+" on the tapped knob and its VoiceOver label "Add between Dinner and Shower".
        public var addBetweenButton: EditClock.AddBetween? {
            guard let index = addBetween, edit.knobs.indices.contains(index) else { return nil }
            let knob = edit.knobs[index]
            return EditClock.AddBetween(knob: index, minute: knob.minute,
                                        label: L10n.tr("day.add_between", edit.blocks[knob.before].title,
                                                       edit.blocks[knob.after].title))
        }

        /// What an All days save does to the school record (layout v37): the School slice's new times
        /// become School's hours. nil when School did not move or this is a This day save.
        public var schoolToSave: Kid? {
            guard saveScope == .allDays, var kid = kidInfo, let school = kid.school,
                  let block = edit.blocks.first(where: { $0.kind == .school }),
                  let was = edit.savedBlocks.first(where: { $0.kind == .school }),
                  block.start != was.start || block.end != was.end else { return nil }
            kid.school = school.moved(sliceStart: block.start, sliceEnd: block.end)
            return kid
        }
        /// Board G1f (layout v41): seven day pictures and "More" (two rows of four), the picked one first.
        public var newSlicePictures: [KitSlot] {
            let picked = newSlice?.iconName.flatMap(KitSlot.init(rawValue:))
            let rest = OurDayFeature.suggested.filter { $0 != picked }
            return Array(([picked].compactMap { $0 } + rest).prefix(7))
        }
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
        case knobAdjusted(index: Int, by: Int)
        /// Board G1e: a tap on a knob shows its "+"; the "+" adds a slice between.
        case knobTapped(Int)
        case addBetweenTapped
        case sliceTapped(start: Int)
        case plusTapped(start: Int)
        case startPicked(Date)
        case endPicked(Date)
        case makeFreeTapped
        /// Board G1f: a picture puts the slice on the clock (named after it); the name and times edit it.
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
        /// Board G8 (layout v36): one "Add"; the form opens on Every week and its Repeat tabs pick the kind.
        case addTapped
        case saveTapped
        case saved(Result<Routine, SaveError>)
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
        }
    }

    public struct SaveError: Error, Equatable {}

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.holidays) var holidays
    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date

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
                state.saveScope = scope
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
                return save(&state)

            case let .knobDragged(index, minute):
                guard state.edit.knobs.indices.contains(index) else { return .none }
                if state.dragging != index {
                    state.addBetween = nil
                    state.dragging = index
                    state.dragOrigin = state.edit.knobs[index].minute
                    state.edit.beginChange()
                }
                let before = state.edit.knobs[index].minute
                let move = state.edit.moveKnob(index, to: minute)
                feel(move, from: before, &state)
                return .none

            case let .knobReleased(index):
                state.dragging = nil
                state.dragOrigin = nil
                state.addBetween = nil
                guard state.edit.knobs.indices.contains(index) else { return .none }
                state.selected = state.edit.closeShortGaps(favoring: moved(byKnob: index, state.edit))
                    ?? state.edit.knobs[index].before
                return .none

            case let .knobAdjusted(index, delta):
                guard state.edit.knobs.indices.contains(index) else { return .none }
                state.edit.beginChange()
                let before = state.edit.knobs[index].minute
                feel(state.edit.moveKnob(index, to: before + delta), from: before, &state)
                state.edit.closeShortGaps(favoring: moved(byKnob: index, state.edit))
                return .none

            case let .knobTapped(index):
                guard state.edit.knobs.indices.contains(index) else { return .none }
                state.addBetween = state.addBetween == index ? nil : index
                return .none

            case .addBetweenTapped:
                guard let index = state.addBetween else { return .none }
                state.addBetween = nil
                dropBetween(&state)
                guard let slot = state.edit.insertBetween(knob: index) else {
                    state.message = L10n.tr("day.add_between.no_room")
                    return .none
                }
                state.selected = slot
                state.newSlice = NewSlice(block: slot, isBetween: true)
                return .none

            case let .sliceTapped(start):
                state.addBetween = nil
                dropBetween(&state)
                state.selected = state.edit.blocks.firstIndex { $0.start == start }
                state.newSlice = nil
                state.message = nil
                return .none

            case let .plusTapped(start):
                state.addBetween = nil
                dropBetween(&state)
                guard let block = state.edit.blocks.firstIndex(where: { $0.start == start && $0.kind == .free })
                else { return .none }
                state.selected = block
                state.newSlice = NewSlice(block: block)
                return .none

            case let .startPicked(date):
                guard let block = state.selected else { return .none }
                let before = state.edit.blocks[block].start
                feel(state.edit.setStart(ofBlock: block, to: Day.minute(of: date, calendar: calendar)),
                     from: before, &state)
                return .none

            case let .endPicked(date):
                guard let block = state.selected else { return .none }
                let before = state.edit.blocks[block].end
                feel(state.edit.setEnd(ofBlock: block, to: Day.minute(of: date, calendar: calendar)),
                     from: before, &state)
                return .none

            case .makeFreeTapped:
                guard let block = state.selected else { return .none }
                // Freed time joins the free time beside it; the joined slice stays selected.
                state.selected = state.edit.makeFree(block)
                return .none

            case let .newSlicePicturePicked(name):
                guard var slice = state.newSlice else { return .none }
                let title = slice.nameIsTyped ? slice.name : String(ItemForm.label(for: name).prefix(Self.longestName))
                if slice.isOnClock {
                    state.edit.restyle(slice.block, title: title, iconName: name, kind: Self.kind(forPicture: name))
                } else {
                    state.edit.fill(slice.block, title: title, iconName: name, kind: Self.kind(forPicture: name))
                    slice.isOnClock = true
                }
                slice.iconName = name
                slice.name = title
                slice.isPickingMore = false
                state.newSlice = slice
                state.selected = slice.block
                return .none

            case let .newSliceNameChanged(text):
                guard var slice = state.newSlice else { return .none }
                slice.name = String(text.prefix(Self.longestName))
                slice.nameIsTyped = true
                if slice.isOnClock, let icon = slice.iconName {
                    let trimmed = slice.name.trimmingCharacters(in: .whitespaces)
                    state.edit.restyle(slice.block, title: trimmed.isEmpty ? ItemForm.label(for: icon) : trimmed,
                                       iconName: icon, kind: Self.kind(forPicture: icon))
                }
                state.newSlice = slice
                return .none

            case .newSliceMoreTapped:
                state.newSlice?.isPickingMore.toggle()
                return .none

            case .undoTapped:
                // Board G1f: Undo takes a new slice back, card and all.
                if state.newSlice?.isOnClock == true { state.newSlice = nil }
                state.edit.undo()
                state.message = nil
                return .none

            case .redoTapped:
                state.edit.redo()
                state.message = nil
                return .none

            case .listTapped:
                return ask(.list(!state.showsList), &state)

            case .settingsTapped:
                return ask(.settings, &state)

            case let .listRowTapped(target):
                switch target {
                case .school: return .none
                case let .item(id): return .send(.delegate(.openItem(id)))
                }

            case .addTapped:
                return .send(.delegate(.add(state.kid, .weekly)))

            case .saveTapped:
                // Spec "Edit scope": All days asks from when first (board G5), like every repeating item.
                if state.saveScope == .allDays, state.fromWhen == nil {
                    state.fromWhen = .today
                    state.fromWhenDate = state.today
                    return .none
                }
                return save(&state)

            case let .saved(.success(routine)):
                state.routines.removeAll {
                    $0.kid == routine.kid && $0.dayType == routine.dayType && $0.from == routine.from
                        && $0.onlyOn == routine.onlyOn
                }
                state.routines.append(routine)
                state.edit.markSaved()
                state.newSlice = nil
                state.saveError = nil
                // Grown-up mode stays on the clock after a save (board G1), unless G1d's Save asked to leave.
                guard state.leavesAfterSave else { return .none }
                state.leavesAfterSave = false
                let next = state.pendingSwitch
                state.pendingSwitch = nil
                return go(next, &state)

            case .saved(.failure):
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

    /// Writes `routineToSave`; the G5 card closes.
    private func save(_ state: inout State) -> Effect<Action> {
        let routine = state.routineToSave
        let kid = state.schoolToSave
        if let kid { state.kids = state.kids.map { $0.id == kid.id ? kid : $0 } }
        state.fromWhen = nil
        return .run { [scheduleStore] send in
            do {
                try await scheduleStore.saveRoutine(routine)
                // Layout v37: School's hours follow the slice (Arrive by, Latest's grace, the end).
                if let kid { try await scheduleStore.saveKid(kid) }
                await send(.saved(.success(routine)))
            } catch {
                await send(.saved(.failure(SaveError())))
            }
        }
    }

    /// The template on the clock's day: the day's own one, else the day type's.
    private func loadTemplate(_ state: inout State) {
        let template = DayPlanner.template(for: state.kid, on: state.day, routines: state.routines,
                                           holidays: state.family.daysOff(state.kid), calendar: calendar)
        state.edit = TemplateEdit(blocks: template?.blocks ?? [])
        state.saveScope = .thisDay
        // Spec "G1 as built": the card is never empty: the slice now on today, else the day's first.
        let now = state.heldMinute ?? (state.day == state.today ? state.nowMinute : nil)
        state.heldMinute = nil
        state.selected = state.edit.blocks.firstIndex { block in now.map { block.start <= $0 && $0 < block.end } ?? false }
            ?? (state.edit.blocks.isEmpty ? nil : 0)
        state.dragging = nil
        state.dragOrigin = nil
        state.newSlice = nil
        state.message = nil
    }

    /// The slice a knob move grew or shrank on purpose: the side that is not free time, so free time
    /// left under 15 minutes joins it ("No forced gaps").
    private func moved(byKnob index: Int, _ edit: TemplateEdit) -> Int {
        let knob = edit.knobs[index]
        return edit.blocks[knob.before].kind == .free ? knob.after : knob.before
    }

    /// Board G1e: a slice put between and closed before a picture was picked is taken back.
    private func dropBetween(_ state: inout State) {
        guard state.newSlice?.isBetween == true, state.newSlice?.isOnClock == false else {
            if state.newSlice?.isOnClock == true { state.newSlice = nil }
            return
        }
        state.newSlice = nil
        state.edit.dropLastChange()
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
        case nil:
            return .none
        }
    }

    /// A light tap per 5-minute step, a stronger one on the hour, a bump at a limit.
    private func feel(_ move: TemplateEdit.Move, from before: Int, _ state: inout State) {
        switch move {
        case let .moved(minute) where minute != before:
            if minute % 60 == 0 { state.haptics.hours += 1 } else { state.haptics.steps += 1 }
        case let .stopped(minute) where minute == before:
            state.haptics.bumps += 1
        case .stopped:
            state.haptics.bumps += 1
        default:
            break
        }
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
