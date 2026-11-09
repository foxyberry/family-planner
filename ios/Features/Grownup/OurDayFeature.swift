import ComposableArchitecture
import DesignSystem
import Domain
import KitArt
import Foundation
import ScheduleStore
import Strings

/// C6 · Our day (spec "C6 · Our day"): a grown-up drags the times of a kid's day template on the
/// clock. The rules live in `TemplateEdit`; this reducer keeps the screen's state and saves the
/// template from tomorrow.
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

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        public var dayType: DayType = .weekday
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
        public var isConfirmingLeave = false
        /// Where to go after "Leave" in the confirm card: another kid or day type, or back.
        public var pendingSwitch: Switch?
        public var saveError: String?
        /// The app's calendar, for the time fields' dates (views never read `Calendar.current`).
        public var calendar: Calendar

        public enum Switch: Equatable, Sendable {
            case kid(Kid.ID)
            case dayType(DayType)
            case back
        }

        public init(kid: Kid.ID, today: Day, calendar: Calendar) {
            self.kid = kid
            self.today = today
            self.calendar = calendar
        }

        /// The selected slice's start and end as dates for the time fields.
        public var startDate: Date { today.date(minute: selectedBlock?.start ?? 0, calendar: calendar) }
        public var endDate: Date { today.date(minute: selectedBlock?.end ?? 0, calendar: calendar) }

        /// Tomorrow: a saved template starts here, so today keeps its old one.
        public func tomorrow(calendar: Calendar) -> Day { today.adding(days: 1, calendar: calendar) }

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
        public var showsHolidayNote: Bool { dayType == .sunday }
        public var canAddNewSlice: Bool {
            guard let newSlice else { return false }
            return !newSlice.name.trimmingCharacters(in: .whitespaces).isEmpty && newSlice.iconName != nil
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case task
        case loaded(ScheduleSnapshot?)
        case kidTabTapped(Kid.ID)
        case dayTypeTapped(DayType)
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
        case saveTapped
        case saved(Result<Routine, SaveError>)
        case backTapped
        case leaveConfirmed
        case leaveCancelled
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Saved or left: the app pops this screen.
            case finished
        }
    }

    public struct SaveError: Error, Equatable {}

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.calendar) var calendar

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                return .run { [scheduleStore] send in await send(.loaded(try? await scheduleStore.load())) }

            case let .loaded(snapshot):
                state.kids = snapshot?.kids ?? []
                state.routines = snapshot?.routines ?? []
                loadTemplate(&state)
                return .none

            case let .kidTabTapped(kid):
                guard kid != state.kid else { return .none }
                return ask(.kid(kid), &state)

            case let .dayTypeTapped(type):
                guard type != state.dayType else { return .none }
                return ask(.dayType(type), &state)

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

            case .saveTapped:
                let routine = Routine(kid: state.kid, dayType: state.dayType, from: state.tomorrow(calendar: calendar),
                                      blocks: state.edit.blocks)
                return .run { [scheduleStore] send in
                    do {
                        try await scheduleStore.saveRoutine(routine)
                        await send(.saved(.success(routine)))
                    } catch {
                        await send(.saved(.failure(SaveError())))
                    }
                }

            case let .saved(.success(routine)):
                state.routines.removeAll { $0.kid == routine.kid && $0.dayType == routine.dayType && $0.from == routine.from }
                state.routines.append(routine)
                state.edit.markSaved()
                state.saveError = nil
                return .send(.delegate(.finished))

            case .saved(.failure):
                state.saveError = L10n.tr("day.save_failed")
                return .none

            case .backTapped:
                return ask(.back, &state)

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

    /// The template the kid uses from tomorrow for the chosen day type.
    private func loadTemplate(_ state: inout State) {
        let tomorrow = state.tomorrow(calendar: calendar)
        let template = state.routines
            .filter { $0.kid == state.kid && $0.dayType == state.dayType && $0.from <= tomorrow }
            .max { $0.from < $1.from }
        state.edit = TemplateEdit(blocks: template?.blocks ?? [])
        state.selected = nil
        state.dragging = nil
        state.dragOrigin = nil
        state.newSlice = nil
        state.message = nil
    }

    /// Unsaved changes ask "Leave without saving?" first.
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
        case let .dayType(type):
            state.dayType = type
            loadTemplate(&state)
            return .none
        case .back:
            return .send(.delegate(.finished))
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
