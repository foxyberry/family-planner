import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import SchoolDirectory
import Strings

/// G7 · Change school (spec "Where the kid goes changes"): search the school list (as on S2), pick
/// one, choose when it starts ("Next term" or a date), Save. Until that day the kid keeps the old
/// school and Settings shows the pending change, which can be changed or cancelled; from that day the
/// new school is the kid's school and the weekday template uses its hours. After Save, Our buses
/// opens for the new trip.
@Reducer
public struct ChangeSchoolFeature {
    public enum StartsOn: Hashable, Sendable { case nextTerm, date }

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        public var stored: Kid?
        public var routines: [Routine] = []
        public var directory: [SchoolEntry] = []
        public var schoolYear: SchoolCalendar = .none
        public var text = ""
        public var matches: [SchoolEntry] = []
        public var picked: SchoolEntry?
        public var startsOn: StartsOn = .nextTerm
        public var date: Day
        public var today: Day
        public var calendar: Calendar
        public var isConfirmingCancel = false
        public var saveError: String?

        public init(kid: Kid.ID, today: Day, calendar: Calendar) {
            self.kid = kid
            self.today = today
            date = today
            self.calendar = calendar
        }

        public var title: String { L10n.tr("change_school.title") }
        public var currentName: String { stored?.school?.name ?? L10n.tr("settings.child.home") }
        /// "From 5 Jan → Example Primary School" while a change waits for its day.
        public var pendingLine: String? {
            guard let pending = stored?.pendingSchool else { return nil }
            return L10n.tr("change_school.pending", DayText.dayMonth(pending.from, calendar: calendar), pending.school.name)
        }
        /// The first day of the next term (the kid's school year), if it is known.
        public var nextTermStart: Day? {
            schoolYear.terms.filter { $0.start > today }.map(\.start).min()
        }
        /// The day the new school starts.
        public var startDay: Day {
            switch startsOn {
            case .nextTerm: nextTermStart ?? date
            case .date: max(date, today)
            }
        }
        public var startLabel: String { DayText.dayMonth(startDay, calendar: calendar) }
        public var dateValue: Date { max(date, today).date(calendar: calendar) }
        public var canSave: Bool { picked != nil && stored != nil }
        public var cancelTitle: String { L10n.tr("change_school.cancel.title", stored?.school?.name ?? "") }

        /// The kid with the change, and the weekday template from its first day on the new hours.
        var change: (kid: Kid, routine: Routine?)? {
            guard var kid = stored, let entry = picked else { return nil }
            let school = School(entry: entry)
            let day = startDay
            if day <= today {
                kid.school = school
                kid.pendingSchool = nil
            } else {
                kid.pendingSchool = PendingSchool(school: school, from: day)
            }
            let first = (0..<7).map { day.adding(days: $0, calendar: calendar) }
                .first { $0.weekday(calendar) != .saturday && $0.weekday(calendar) != .sunday } ?? day
            let routine = DayPlanner.template(for: kid.id, on: first, routines: routines, holidays: [], calendar: calendar)
                .map { Routine(kid: kid.id, dayType: .weekday, from: day, blocks: TemplateEdit.movingSchool($0.blocks, to: school)) }
            return (kid, routine)
        }

        /// "Cancel the change": the template from the pending day goes back to the old school's hours.
        var cancel: (kid: Kid, routine: Routine?)? {
            guard var kid = stored, let pending = kid.pendingSchool, let school = kid.school else { return nil }
            kid.pendingSchool = nil
            let routine = DayPlanner.template(for: kid.id, on: pending.from, routines: routines, holidays: [], calendar: calendar)
                .map { Routine(kid: kid.id, dayType: .weekday, from: pending.from,
                               blocks: TemplateEdit.movingSchool($0.blocks, to: school)) }
            return (kid, routine)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?, directory: [SchoolEntry], year: SchoolCalendar)
        case textChanged(String)
        case picked(SchoolEntry)
        case startsOnTapped(StartsOn)
        case datePicked(Date)
        case saveTapped
        case saved(Bool)
        /// "Cancel the change": asks once ("Stay at {old school}?"), then removes the pending change.
        case cancelChangeTapped
        case cancelConfirmed
        case cancelKept
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
            /// After Save, Our buses opens for the new trip (spec: S3 for the new place).
            case openBuses(Kid.ID)
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.schoolDirectory) var schoolDirectory

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let kid = state.kid
                return .run { [scheduleStore, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    let directory = await schoolDirectory.schools()
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: [])
                    await send(.loaded(snapshot, directory: directory, year: family.schools[kid] ?? .none))
                }

            case let .loaded(snapshot, directory, year):
                state.stored = snapshot?.kids.first { $0.id == state.kid }
                state.routines = snapshot?.routines ?? []
                state.directory = directory
                state.schoolYear = year
                if state.nextTermStart == nil { state.startsOn = .date }
                return .none

            case let .textChanged(text):
                state.text = text
                state.picked = nil
                state.matches = SchoolSearch.matches(text, in: state.directory)
                return .none

            case let .picked(entry):
                state.picked = entry
                state.text = entry.name
                state.matches = []
                return .none

            case let .startsOnTapped(choice):
                state.startsOn = choice
                return .none

            case let .datePicked(date):
                state.startsOn = .date
                state.date = max(Day(date, calendar: state.calendar), state.today)
                return .none

            case .saveTapped:
                guard state.canSave, let change = state.change else { return .none }
                return .run { [scheduleStore] send in
                    do {
                        try await scheduleStore.saveKid(change.kid)
                        if let routine = change.routine { try await scheduleStore.saveRoutine(routine) }
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case let .saved(ok):
                guard ok else {
                    state.saveError = L10n.tr("day.save_failed")
                    return .none
                }
                return .send(.delegate(.openBuses(state.kid)))

            case .cancelChangeTapped:
                state.isConfirmingCancel = true
                return .none

            case .cancelKept:
                state.isConfirmingCancel = false
                return .none

            case .cancelConfirmed:
                state.isConfirmingCancel = false
                guard let cancel = state.cancel else { return .none }
                state.stored = cancel.kid
                return .run { [scheduleStore] _ in
                    try? await scheduleStore.saveKid(cancel.kid)
                    if let routine = cancel.routine { try? await scheduleStore.saveRoutine(routine) }
                }

            case .backTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
