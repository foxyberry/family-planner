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
    /// S2's "Goes to" (design session 2026-11-15: G7 reuses S2's top rows).
    public enum Place: Hashable, Sendable { case school, preschool, home }

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        public var stored: Kid?
        public var routines: [Routine] = []
        public var directory: [SchoolEntry] = []
        public var schoolYear: SchoolCalendar = .none
        /// The picked school's own year (board G7: Next term is the new school's next term).
        public var pickedYear: SchoolCalendar?
        public var text = ""
        public var matches: [SchoolEntry] = []
        public var picked: SchoolEntry?
        public var startsOn: StartsOn = .nextTerm
        /// The "Goes to" tab: the kid's place now until a grown-up taps another.
        public var place: Place = .school
        /// Preschool: the typed name, drop-off and pick-up (minutes after midnight).
        public var preschoolName = ""
        /// They start on the S2 defaults, which count as answers (user, 2026-11-18).
        public var dropOff = School.defaultStart
        public var pickUp = School.defaultEnd
        /// The "Starts on" card is open (after a school pick, Preschool's Save, or At home).
        public var isCardOpen = false
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
            return L10n.tr("change_school.pending", DayText.dayMonth(pending.from, calendar: calendar),
                           pending.school?.name ?? L10n.tr("settings.child.home"))
        }

        /// The kid's place now (the tab picked when the screen opens).
        public var currentPlace: Place {
            guard let school = stored?.school else { return .home }
            return school.isPreschool ? .preschool : .school
        }
        public var placeTabs: [(Place, String)] {
            [(.school, L10n.tr("s2.goes.school")), (.preschool, L10n.tr("s2.goes.preschool")),
             (.home, L10n.tr("s2.goes.home"))]
        }
        /// Preschool's rows show "Save", which opens the card once the name and both times are in.
        public var canContinuePreschool: Bool {
            guard place == .preschool else { return false }
            return !preschoolName.trimmingCharacters(in: .whitespaces).isEmpty && dropOff < pickUp
        }
        /// A time as the field prints it.
        public func timeLabel(_ minute: Int) -> String { TimeText.withPeriod(minute) }
        public func timeDate(_ minute: Int) -> Date {
            Day(year: 2026, month: 1, day: 1).date(minute: minute, calendar: calendar)
        }

        /// The new place: the picked school, the typed preschool, or nil for at home.
        public var newSchool: School? {
            switch place {
            case .school: return picked.map(School.init(entry:))
            case .preschool:
                guard canContinuePreschool else { return nil }
                return School(name: preschoolName.trimmingCharacters(in: .whitespaces), days: Weekday.schoolDays,
                              start: dropOff, end: pickUp, arriveBy: dropOff, kind: .preschool)
            case .home: return nil
            }
        }
        /// The card's title: the new place's name, or "At home".
        public var cardTitle: String { newSchool?.name ?? L10n.tr("settings.child.home") }
        /// The first day of the next term (the kid's school year), if it is known.
        public var nextTermStart: Day? {
            (pickedYear ?? schoolYear).terms.filter { $0.start > today }.map(\.start).min()
        }
        /// The day the new school starts.
        public var startDay: Day {
            switch startsOn {
            case .nextTerm: nextTermStart ?? date
            case .date: max(date, today)
            }
        }
        public var startLabel: String { DayText.dayMonth(startDay, calendar: calendar) }
        /// Board G7: the "Starts on" card opens once a school is picked.
        public var isShowingStartsOn: Bool { isCardOpen }
        public var startsOnTabs: [(StartsOn, String)] {
            [(.nextTerm, L10n.tr("change_school.next_term")), (.date, L10n.tr("change_school.date"))]
        }
        /// Board G7: "Mon 4 Jan · Term 1" under Next term; nothing under Date (the date field says it).
        public var startsOnCaption: String? {
            guard startsOn == .nextTerm, let start = nextTermStart else { return nil }
            let term = (pickedYear ?? schoolYear).terms.first { $0.start == start }?.name ?? ""
            return L10n.tr("change_school.next_term.caption", DayText.short(start, calendar: calendar), term)
        }
        public var dateValue: Date { max(date, today).date(calendar: calendar) }
        public var canSave: Bool {
            guard stored != nil else { return false }
            switch place {
            case .school: return picked != nil
            case .preschool: return canContinuePreschool
            case .home: return currentPlace != .home || stored?.pendingSchool != nil
            }
        }
        public var cancelTitle: String { L10n.tr("change_school.cancel.title", currentName) }

        /// The kid with the change, and the weekday template from its first day on the new hours.
        var change: (kid: Kid, routine: Routine?)? {
            guard var kid = stored, canSave else { return nil }
            let school = newSchool
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
                .map { Routine(kid: kid.id, dayType: .weekday, from: day, blocks: TemplateEdit.placingSchool($0.blocks, school: school)) }
            return (kid, routine)
        }

        /// "Cancel the change": the template from the pending day goes back to the old school's hours.
        var cancel: (kid: Kid, routine: Routine?)? {
            guard var kid = stored, let pending = kid.pendingSchool else { return nil }
            kid.pendingSchool = nil
            let routine = DayPlanner.template(for: kid.id, on: pending.from, routines: routines, holidays: [], calendar: calendar)
                .map { Routine(kid: kid.id, dayType: .weekday, from: pending.from,
                               blocks: TemplateEdit.placingSchool($0.blocks, school: kid.school)) }
            return (kid, routine)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?, directory: [SchoolEntry], year: SchoolCalendar)
        case textChanged(String)
        case picked(SchoolEntry)
        case placeTapped(Place)
        case preschoolNameChanged(String)
        case dropOffPicked(Date)
        case pickUpPicked(Date)
        case preschoolSaveTapped
        case startsOnTapped(StartsOn)
        /// The G7 card's Cancel: no school picked, back to the search.
        case cardCancelled
        case pickedYearLoaded(SchoolCalendar)
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
                state.place = state.currentPlace
                if state.nextTermStart == nil { state.startsOn = .date }
                return .none

            case let .textChanged(text):
                // The field sends its text again when it loses focus (the G7 card hides the keyboard):
                // the same text keeps the pick.
                guard text != state.text else { return .none }
                state.text = text
                state.picked = nil
                state.matches = SchoolSearch.matches(text, in: state.directory)
                return .none

            case let .picked(entry):
                state.picked = entry
                state.pickedYear = nil
                state.text = entry.name
                state.matches = []
                state.isCardOpen = true
                let age = state.stored?.age ?? 7
                return .run { [schoolDirectory] send in
                    await send(.pickedYearLoaded(await schoolDirectory.calendar(School(entry: entry), age)))
                }

            case let .pickedYearLoaded(year):
                state.pickedYear = year
                state.startsOn = state.nextTermStart == nil ? .date : .nextTerm
                return .none

            case let .placeTapped(place):
                state.place = place
                state.picked = nil
                state.pickedYear = nil
                state.text = ""
                state.matches = []
                // Design session 2026-11-15: At home goes straight to the "Starts on" card.
                if place == .home, state.canSave { state.isCardOpen = true }
                return .none

            case let .preschoolNameChanged(name):
                guard name != state.preschoolName else { return .none }
                state.preschoolName = name
                return .none

            case let .dropOffPicked(date):
                state.dropOff = Day.minute(of: date, calendar: state.calendar)
                return .none

            case let .pickUpPicked(date):
                state.pickUp = Day.minute(of: date, calendar: state.calendar)
                return .none

            case .preschoolSaveTapped:
                guard state.canContinuePreschool else { return .none }
                state.isCardOpen = true
                return .none

            case .cardCancelled:
                state.isCardOpen = false
                guard state.place == .school else { return .none }
                state.picked = nil
                state.pickedYear = nil
                state.text = ""
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
                state.isCardOpen = false
                // A kid at home has no trip: back to G4 instead of the new trip's screen.
                return .send(.delegate(state.place == .home ? .finished : .openBuses(state.kid)))

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
