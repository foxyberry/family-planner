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

    public struct NewSlice: Equatable, Sendable {
        public var block: Int
        public var name: String
        public var iconName: String?

        public init(block: Int, name: String = "", iconName: String? = nil) {
            self.block = block
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

    /// "This day" or "All days" (spec "Edit scope"): a drag changes this day unless All days is picked.
    public enum Scope: Hashable, Sendable { case thisDay, allDays }

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        /// The date on the clock (board G1's day button).
        public var day: Day
        public var saveScope: Scope = .thisDay
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
        public var haptics = Haptics()
        /// Board G1d: "Save the changes?" before leaving with unsaved drags.
        public var isConfirmingLeave = false
        /// The G1d card's Save: leave once the save has gone through.
        public var leavesAfterSave = false
        /// Where to go after Save or "Don't save" in the G1d card: another kid or day, or back.
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
            return [ListSection(title: L10n.tr("list.every_week"), rows: weekly),
                    ListSection(title: L10n.tr("list.once"), rows: once)].filter { !$0.rows.isEmpty }
        }

        /// Board G1: Undo and Redo, each on when it has a step to take.
        public var canUndo: Bool { edit.isChanged }
        public var canRedo: Bool { edit.canRedo }

        public init(kid: Kid.ID, today: Day, calendar: Calendar) {
            self.kid = kid
            self.today = today
            self.day = today
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
        public func pickerWeekday(_ day: Day) -> String { DayText.shortName(day.weekday(calendar)) }

        /// Board G1d: the first changed slice as "Dinner 6:30 pm → 7:30 pm, this day".
        public var unsavedLine: String? {
            guard edit.isChanged, let block = edit.firstChange else { return nil }
            return L10n.tr("day.unsaved.line", block.title, TimeText.withPeriod(block.start), TimeText.withPeriod(block.end),
                           saveScope == .thisDay ? L10n.tr("day.unsaved.this_day") : L10n.tr("day.unsaved.all_days"))
        }

        /// The selected slice's start and end as dates for the time fields.
        public var startDate: Date { day.date(minute: selectedBlock?.start ?? 0, calendar: calendar) }
        public var endDate: Date { day.date(minute: selectedBlock?.end ?? 0, calendar: calendar) }

        /// What Save writes: this day's own template, or the day type's template from this day on
        /// (never from before today).
        public var routineToSave: Routine {
            switch saveScope {
            case .thisDay:
                Routine.day(day, kid: kid, dayType: dayType, blocks: edit.blocks)
            case .allDays:
                Routine(kid: kid, dayType: dayType, from: max(day, today), blocks: edit.blocks)
            }
        }

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
                EditClock.Knob(minute: knob.minute, isLocked: knob.isLocked,
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
            return EditClock.Hub(title: selected.map { edit.blocks[$0].title })
        }

        public var selectedBlock: RoutineBlock? { selected.map { edit.blocks[$0] } }
        public var startLabel: String? { selectedBlock.map { TimeText.withPeriod($0.start) } }
        public var endLabel: String? { selectedBlock.map { TimeText.withPeriod($0.end) } }
        public var canMakeFree: Bool { selectedBlock.map { !$0.isLocked && $0.kind != .free } ?? false }
        public var canAddNewSlice: Bool {
            guard let newSlice else { return false }
            return !newSlice.name.trimmingCharacters(in: .whitespaces).isEmpty && newSlice.iconName != nil
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
        case pickerTodayTapped
        case pickerClosed
        case scopeTapped(Scope)
        case knobDragged(index: Int, minute: Int)
        case knobReleased(Int)
        case knobAdjusted(index: Int, by: Int)
        case lockedKnobTapped(Int)
        case sliceTapped(start: Int)
        case plusTapped(start: Int)
        case startPicked(Date)
        case endPicked(Date)
        case makeFreeTapped
        case newSlicePicturePicked(String)
        case newSliceAddTapped
        case undoTapped
        case redoTapped
        /// Board G1 header: List (a toggle) and Settings.
        case listTapped
        case settingsTapped
        /// Board G8: a row (School or an item) and the side column's adds.
        case listRowTapped(ListSection.Target)
        case addWeeklyTapped
        case addOnceTapped
        case saveTapped
        case saved(Result<Routine, SaveError>)
        case backTapped
        /// Board G1d: Save, "Don't save" or Cancel.
        case unsavedSaveTapped
        case leaveConfirmed
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
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [],
                                                             publicHolidays: await holidays.holidays(year).map(\.day))
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
                    let back = (state.day.weekday(calendar).rawValue + 5) % 7
                    state.pickerStart = state.day.adding(days: -back, calendar: calendar)
                }
                return .none

            case let .pickerPageTapped(step):
                state.pickerStart = state.pickerStart?.adding(days: 14 * step, calendar: calendar)
                return .none

            case let .pickerDayTapped(day):
                state.pickerStart = nil
                guard day != state.day else { return .none }
                return ask(.day(day), &state)

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

            case let .knobDragged(index, minute):
                guard state.edit.knobs.indices.contains(index) else { return .none }
                if state.dragging != index {
                    state.dragging = index
                    state.dragOrigin = state.edit.knobs[index].minute
                    state.edit.beginChange()
                }
                let before = state.edit.knobs[index].minute
                let move = state.edit.moveKnob(index, to: minute)
                feel(move, from: before, &state)
                state.message = state.edit.effect(ofKnob: index)
                return .none

            case let .knobReleased(index):
                state.dragging = nil
                state.dragOrigin = nil
                state.selected = state.edit.knobs.indices.contains(index) ? state.edit.knobs[index].before : state.selected
                return .none

            case let .knobAdjusted(index, delta):
                guard state.edit.knobs.indices.contains(index) else { return .none }
                state.edit.beginChange()
                let before = state.edit.knobs[index].minute
                feel(state.edit.moveKnob(index, to: before + delta), from: before, &state)
                state.message = state.edit.effect(ofKnob: index)
                return .none

            case .lockedKnobTapped:
                state.message = L10n.tr("day.locked")
                return .none

            case let .sliceTapped(start):
                state.selected = state.edit.blocks.firstIndex { $0.start == start }
                state.newSlice = nil
                state.message = nil
                return .none

            case let .plusTapped(start):
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
                state.newSlice?.iconName = name
                return .none

            case .newSliceAddTapped:
                guard state.canAddNewSlice, let slice = state.newSlice, let icon = slice.iconName else { return .none }
                state.edit.fill(slice.block, title: slice.name.trimmingCharacters(in: .whitespaces), iconName: icon,
                                kind: Self.kind(forPicture: icon))
                state.newSlice = nil
                return .none

            case .undoTapped:
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

            case .addWeeklyTapped:
                return .send(.delegate(.add(state.kid, .weekly)))

            case .addOnceTapped:
                return .send(.delegate(.add(state.kid, .once)))

            case .saveTapped:
                let routine = state.routineToSave
                return .run { [scheduleStore] send in
                    do {
                        try await scheduleStore.saveRoutine(routine)
                        await send(.saved(.success(routine)))
                    } catch {
                        await send(.saved(.failure(SaveError())))
                    }
                }

            case let .saved(.success(routine)):
                state.routines.removeAll {
                    $0.kid == routine.kid && $0.dayType == routine.dayType && $0.from == routine.from
                        && $0.onlyOn == routine.onlyOn
                }
                state.routines.append(routine)
                state.edit.markSaved()
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

            case .leaveConfirmed:
                state.isConfirmingLeave = false
                let next = state.pendingSwitch
                state.pendingSwitch = nil
                return go(next, &state)

            case .leaveCancelled:
                state.isConfirmingLeave = false
                state.pendingSwitch = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// The template on the clock's day: the day's own one, else the day type's.
    private func loadTemplate(_ state: inout State) {
        let template = DayPlanner.template(for: state.kid, on: state.day, routines: state.routines,
                                           holidays: state.family.daysOff(state.kid), calendar: calendar)
        state.edit = TemplateEdit(blocks: template?.blocks ?? [])
        state.saveScope = .thisDay
        state.selected = nil
        state.dragging = nil
        state.dragOrigin = nil
        state.newSlice = nil
        state.message = nil
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
        case .locked:
            state.message = L10n.tr("day.locked")
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
