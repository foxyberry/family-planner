import AppSettings
import ComposableArchitecture
import Domain
import Foundation
import Grownup
import Localization
import ParentAuthClient
import SchoolDirectory
import ScheduleStore
import Strings

/// First-run setup (spec "S1–S4", boards S1, S2, S2s, S3, S4): Family → School → Getting to school
/// (once per kid with a school) → Almost done. Going back keeps every value; nothing is saved until
/// "Start" on S4, so quitting before that starts again at S1. No grown-up lock: there is no family yet.
@Reducer
public struct SetupFeature {
    public enum Step: Hashable, Sendable {
        case family
        case school
        /// S3: every kid who goes somewhere, one tab each (layout v17).
        case gettingThere
        case almostDone

        /// "Step n of 4".
        public var number: Int {
            switch self {
            case .family: 1
            case .school: 2
            case .gettingThere: 3
            case .almostDone: 4
            }
        }
    }

    @ObservableState
    public struct State: Equatable, GrownupWords {
        public var strings = Localizer.injected
        public static let mostKids = 4

        public var step: Step = .family
        public var kids: IdentifiedArrayOf<KidEntry>
        /// S2's kid tab.
        public var schoolTab: KidEntry.ID
        /// S3's kid tab (the first going kid when nil or gone).
        public var goingTab: KidEntry.ID?
        /// The bundled school lists, loaded once.
        public var directory: [SchoolEntry] = []
        public var isSaving = false
        public var saveFailed = false
        /// Start worked; setup is closing and never saves again.
        public var isSaved = false
        /// A debug link opened setup over an existing family: Start asks before replacing it.
        public var replacesFamily = false
        public var isConfirmingReplace = false
        /// S4: the feature switches, saved with Start.
        public var settings = AppSettings.defaults
        /// S4: turning the lock on checks Face ID first; while it runs the switch waits.
        public var isCheckingLock = false
        /// S4: the lock could not be turned on (no Face ID, or it failed).
        public var lockNeedsFaceID = false
        /// This iPad has Touch ID (the S4 lock row names it).
        public var isTouchID = false
        /// S1: the kid whose × asks "Remove {name}?" (a card with something typed asks first).
        public var removeConfirm: KidEntry.ID?

        /// S1 (layout v13): every card has a × while there are two or more.
        public var canRemoveKids: Bool { kids.count >= 2 }
        /// Data sources (spec S2), opened from the link under the school caption.
        @Presents public var dataSources: DataSourcesFeature.State?
        /// S3 "+ A bus that changes…" or a change pill: C2c over S3, editing the going form's buses
        /// that change in memory (nothing is saved before Start).
        @Presents public var changeBuses: ChangeBusesFeature.State?
        /// The app's calendar, for the time wheels (minutes after midnight in its time zone).
        public var calendar: Calendar

        public init(firstKid: UUID, calendar: Calendar) {
            kids = [KidEntry(id: firstKid, colorIndex: 0)]
            schoolTab = firstKid
            self.calendar = calendar
        }

        // MARK: S1

        public var canAddKid: Bool { kids.count < Self.mostKids }

        /// "Next →" is off until every card has a name and an age.
        /// S1: every card has a name, an age and a face (user, 2026-11-09: the face too).
        public var familyIsComplete: Bool {
            kids.allSatisfy { !$0.trimmedName.isEmpty && $0.age != nil && $0.face != nil }
        }

        // MARK: S2

        /// The kids S3 asks about (school or preschool), in tab order.
        public var goingKids: [KidEntry] { kids.filter(\.goesOut) }

        public var tabKid: KidEntry? { kids[id: schoolTab] ?? kids.first }

        /// Next stays off until every kid has a pick and every school or preschool form is complete.
        public var schoolIsComplete: Bool { kids.allSatisfy(\.placeIsComplete) }

        // MARK: S3

        public var goingKid: KidEntry? {
            guard step == .gettingThere else { return nil }
            let kids = goingKids
            return kids.first { $0.id == goingTab } ?? kids.first
        }

        /// The S3 stop field of the kid on screen (a placeholder elsewhere).
        public var goingSearch: StopSearchFeature.State {
            get { goingKid?.going.search ?? StopSearchFeature.State() }
            set { if let id = goingKid?.id { kids[id: id]?.going.search = newValue } }
        }

        /// Layout v14: the S2 school list or the S3 stop list is open, and the screen is veiled.
        public var isResultListOpen: Bool {
            switch step {
            case .school: tabKid?.school.isListOpen ?? false
            case .gettingThere: goingSearch.isListOpen
            case .family, .almostDone: false
            }
        }

        public var canGoNext: Bool {
            switch step {
            case .family: familyIsComplete
            case .school: schoolIsComplete
            case .gettingThere: goingKids.allSatisfy(\.going.isFinished)
            case .almostDone: !isSaving && !isSaved
            }
        }

        // MARK: Saving

        /// Everything "Start" writes: kids, starter templates and missions, and bus plans.
        public func family(from: Day, id: () -> UUID) -> ScheduleSnapshot {
            let kids = kids.map(\.kid)
            let entries = self.kids
            let routines = kids.flatMap { kid in
                StarterDays.routines(for: kid, trip: kid.school == nil ? nil : entries[id: kid.id]?.going.trip, from: from)
            }
            let missions = kids.flatMap { StarterDays.missions(for: $0, id: id) }
            let plans = entries.filter(\.goesOut).compactMap { $0.busPlan }
            return ScheduleSnapshot(kids: kids, routines: routines, items: [], missions: missions, busPlans: plans)
        }
    }

    public enum Action: Equatable {
        case task
        case directoryLoaded([SchoolEntry])
        case backTapped
        case nextTapped
        // S1
        case nameChanged(KidEntry.ID, String)
        case ageChanged(KidEntry.ID, String)
        case colourTapped(KidEntry.ID, Int)
        case faceTapped(KidEntry.ID, String)
        case addKidTapped
        case removeKidTapped(KidEntry.ID)
        case removeConfirmed
        case removeCancelled
        // S2
        case schoolTabTapped(KidEntry.ID)
        case goesToTapped(GoesTo)
        case dataSourcesTapped
        case dataSources(PresentationAction<DataSourcesFeature.Action>)
        case schoolTextChanged(String)
        case schoolPicked(SchoolEntry)
        case notInListTapped
        /// A tap on the veil around an open result list.
        case resultVeilTapped
        case dayToggled(Weekday)
        case timeChanged(TimeRow, Int)
        /// A time wheel moved.
        case timePicked(TimeRow, Date)
        case moeTermsToggled
        case moeAnswered(Bool)
        // S3
        case goingTabTapped(KidEntry.ID)
        /// A header kid tab on S2 or S3.
        case kidTabTapped(KidEntry.ID)
        case wayPicked(Way)
        case stopSearch(StopSearchFeature.Action)
        case serviceTapped(String)
        case walkChanged(Int)
        case rideChanged(service: String?, minutes: Int)
        case leaveChanged(Int)
        case changeLinkTapped
        case changeTapped(Int)
        case changeBuses(PresentationAction<ChangeBusesFeature.Action>)
        // S4
        case settingTapped(AppSetting)
        case lockChecked(ParentAuthOutcome)
        case replaceConfirmed
        case replaceCancelled
        case saved(Bool)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// The family is saved; open the home.
            case finished
        }
    }


    /// S2's four times.
    public enum TimeRow: Hashable, Sendable { case start, end, arriveBy, latest }

    @Dependency(\.appSettings) var appSettings
    @Dependency(\.parentAuth) var parentAuth
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.goingSearch, action: \.stopSearch) { StopSearchFeature() }
        Reduce { state, action in
            switch action {
            case .task:
                state.isTouchID = parentAuth.biometry() == .touchID
                guard state.directory.isEmpty else { return .none }
                return .run { [schoolDirectory] send in await send(.directoryLoaded(await schoolDirectory.schools())) }

            case let .directoryLoaded(schools):
                state.directory = schools
                return .none

            case .backTapped:
                switch state.step {
                case .family: break
                case .school: state.step = .family
                case .gettingThere: state.step = .school
                case .almostDone: state.step = state.goingKids.isEmpty ? .school : .gettingThere
                }
                return .none

            case .nextTapped:
                guard state.canGoNext else { return .none }
                switch state.step {
                case .family:
                    state.step = .school
                    if state.kids[id: state.schoolTab] == nil, let first = state.kids.first { state.schoolTab = first.id }
                case .school:
                    state.step = state.goingKids.isEmpty ? .almostDone : .gettingThere
                case .gettingThere:
                    state.step = .almostDone
                case .almostDone:
                    if state.replacesFamily, !state.isConfirmingReplace {
                        state.isConfirmingReplace = true
                        return .none
                    }
                    state.isConfirmingReplace = false
                    state.isSaving = true
                    state.saveFailed = false
                    let today = Day(now, calendar: calendar)
                    let family = state.family(from: Day(year: today.year, month: 1, day: 1), id: { uuid() })
                    let settings = state.settings
                    return .run { [scheduleStore, appSettings] send in
                        do {
                            try await scheduleStore.replaceFamily(family)
                            appSettings.save(settings)
                            await send(.saved(true))
                        } catch {
                            await send(.saved(false))
                        }
                    }
                }
                return .none

            // MARK: S1

            case let .nameChanged(id, name):
                state.kids[id: id]?.name = name
                return .none

            case let .ageChanged(id, text):
                state.kids[id: id]?.ageText = String(text.filter(\.isNumber).prefix(2))
                return .none

            case let .colourTapped(id, colour):
                // Two kids never share a colour: picking a taken one swaps the two kids' colours.
                guard let old = state.kids[id: id]?.colorIndex, old != colour else { return .none }
                if let other = state.kids.first(where: { $0.colorIndex == colour }) {
                    state.kids[id: other.id]?.colorIndex = old
                }
                state.kids[id: id]?.colorIndex = colour
                return .none

            case let .faceTapped(id, face):
                state.kids[id: id]?.face = face
                return .none

            case .addKidTapped:
                guard state.canAddKid else { return .none }
                let used = Set(state.kids.map(\.colorIndex))
                let colour = (0..<KidEntry.colours).first { !used.contains($0) } ?? 0
                state.kids.append(KidEntry(id: uuid(), colorIndex: colour))
                return .none

            case let .removeKidTapped(id):
                guard state.canRemoveKids, let kid = state.kids[id: id] else { return .none }
                // An empty card goes at once; one with a name or an age asks first.
                if kid.trimmedName.isEmpty, kid.ageText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Self.remove(id, from: &state)
                } else {
                    state.removeConfirm = id
                }
                return .none

            case .removeConfirmed:
                if let id = state.removeConfirm { Self.remove(id, from: &state) }
                state.removeConfirm = nil
                return .none

            case .removeCancelled:
                state.removeConfirm = nil
                return .none

            // MARK: S2

            case let .schoolTabTapped(id):
                state.schoolTab = id
                return .none

            case let .goesToTapped(place):
                guard let id = state.tabKid?.id else { return .none }
                state.kids[id: id]?.goesToChoice = place
                updateSchool(&state) { school in
                    let kind: SchoolKind = place == .preschool ? .preschool : .school
                    guard school.kind != kind else { return }
                    // A preschool has no list yet: its name is typed; a school starts from the search.
                    school = SchoolForm()
                    school.kind = kind
                }
                return .none

            case .dataSourcesTapped:
                state.dataSources = DataSourcesFeature.State()
                return .none

            case .dataSources(.presented(.backTapped)):
                state.dataSources = nil
                return .none

            case .dataSources:
                return .none

            case let .schoolTextChanged(text):
                // The field sends its text again when the keyboard closes after a pick: the same
                // text keeps the pick (the list stayed open on the iPad, 2026-11-15).
                guard text != state.tabKid?.school.text else { return .none }
                updateSchool(&state) { school in
                    school.text = text
                    school.picked = nil
                    school.typedByHand = false
                    school.isListClosed = false
                }
                let open = state.tabKid?.school.isListOpen ?? false
                let matches = open ? SchoolSearch.matches(text, in: state.directory) : []
                updateSchool(&state) { $0.matches = matches }
                return .none

            case let .schoolPicked(entry):
                let source = entry.hours.map {
                    L10n.tr("s2.hours.source", DayText.dayMonth($0.checked, calendar: state.calendar))
                }
                updateSchool(&state) { school in
                    school.picked = entry
                    school.text = entry.name
                    school.matches = []
                    school.days = Weekday.schoolDays
                    school.moeAnswer = nil
                    school.usesMoeTerms = entry.followsMoeTerms ?? false
                    // Hours from the school's own website (Latest = the start + 10 minutes), else
                    // the defaults.
                    school.resetTimes()
                    if let hours = entry.hours {
                        school.start = hours.start
                        school.end = hours.end
                        school.arriveBy = hours.start
                        school.latest = hours.start + School.defaultGrace
                    }
                    school.hoursSource = source
                    school.websiteDays = entry.hours?.byWeekday ?? [:]
                }
                return .none

            case .notInListTapped:
                updateSchool(&state) { school in
                    school.typedByHand = true
                    school.picked = nil
                    school.matches = []
                    school.resetTimes()
                    school.hoursSource = nil
                    school.websiteDays = [:]
                    school.usesMoeTerms = false
                    school.moeAnswer = nil
                }
                return .none

            case let .dayToggled(day):
                updateSchool(&state) { school in
                    if school.days.contains(day) { school.days.remove(day) } else { school.days.insert(day) }
                }
                return .none

            case let .timeChanged(row, minute):
                let minute = min(max(minute, 0), 1439)
                updateSchool(&state) { school in
                    switch row {
                    case .start: school.start = minute
                    case .end: school.end = minute
                    case .arriveBy: school.arriveBy = minute
                    case .latest: school.latest = minute
                    }
                    // Editing a value removes "From the school website".
                    school.hoursSource = nil
                    school.websiteDays = [:]
                }
                return .none

            case let .timePicked(row, date):
                return .send(.timeChanged(row, Day.minute(of: date, calendar: state.calendar)))

            case .moeTermsToggled:
                updateSchool(&state) { $0.usesMoeTerms.toggle() }
                return .none

            case let .moeAnswered(yes):
                updateSchool(&state) { school in
                    school.moeAnswer = yes
                    school.usesMoeTerms = yes
                }
                return .none

            // MARK: S3

            case let .kidTabTapped(id):
                return .send(state.step == .gettingThere ? .goingTabTapped(id) : .schoolTabTapped(id))

            case let .goingTabTapped(id):
                // A search still running belongs to the kid on screen: stop it before the tab changes.
                let close = state.goingSearch.isListOpen || state.goingSearch.stop.count < 5
                state.goingTab = id
                return close ? .send(.stopSearch(.listClosed)) : .none

            case let .wayPicked(way):
                updateGoing(&state) { $0.way = way }
                return .none

            case .stopSearch:
                // A new stop (a full code or a pick): the buses picked for the old one (and the buses
                // that change from it) no longer apply. Typing a name, or the field sending its text
                // again, keeps them (user review 2026-11-14).
                updateGoing(&state) { going in
                    guard going.search.stop != going.busesStop else { return }
                    going.services = []
                    going.rides = [:]
                    going.changes = []
                    going.busesStop = going.search.stop
                }
                return .none

            case .resultVeilTapped:
                switch state.step {
                case .school:
                    updateSchool(&state) { $0.isListClosed = true }
                    return .none
                case .gettingThere:
                    return .send(.stopSearch(.listClosed))
                case .family, .almostDone:
                    return .none
                }

            case let .serviceTapped(service):
                // Spec "Several buses": S3 sets the same equal buses as C2.
                updateGoing(&state) { going in
                    going.services = BusPlan.toggling(service, in: going.services, order: going.search.servicesAtStop)
                    if going.services.contains(service), going.rides[service] == nil { going.rides[service] = going.ride }
                }
                return .none

            case let .walkChanged(value):
                updateGoing(&state) { $0.walk = min(max(value, 0), 60) }
                return .none

            case let .rideChanged(service, value):
                updateGoing(&state) { going in
                    let minutes = min(max(value, 0), 90)
                    if let service { going.rides[service] = minutes } else { going.ride = minutes }
                }
                return .none

            case let .leaveChanged(value):
                updateGoing(&state) { $0.leaveBefore = min(max(value, 0), 90) }
                return .none

            case .changeLinkTapped:
                state.changeBuses = state.changeEditor(index: nil)
                return .none

            case let .changeTapped(index):
                guard let going = state.goingKid?.going, going.changes.indices.contains(index) else { return .none }
                state.changeBuses = state.changeEditor(index: index)
                return .none

            case let .changeBuses(.presented(.delegate(.saved(changes)))):
                // Spec "Several buses": C2c comes back to S3 with the route's buses that change.
                updateGoing(&state) { $0.changes = changes }
                state.changeBuses = nil
                return .none

            case .changeBuses(.presented(.delegate(.cancelled))):
                state.changeBuses = nil
                return .none

            case .changeBuses:
                return .none

            // MARK: S4

            case let .settingTapped(setting):
                switch setting {
                case .grownupLock:
                    guard !state.isCheckingLock else { return .none }
                    if state.settings.grownupLock {
                        // Off needs no check and no dialog (spec: the caption warns instead).
                        state.settings.grownupLock = false
                        return .none
                    }
                    // On: check Face ID works first, once.
                    state.isCheckingLock = true
                    return .run { [parentAuth] send in
                        await send(.lockChecked(parentAuth.authenticate(L10n.tr("auth.reason"))))
                    }
                case .medals:
                    state.settings.medals.toggle()
                }
                return .none

            case let .lockChecked(outcome):
                state.isCheckingLock = false
                switch outcome {
                case .success:
                    state.settings.grownupLock = true
                    state.lockNeedsFaceID = false
                case .notAvailable, .notRecognised, .lockedOut:
                    state.lockNeedsFaceID = true
                case .cancelled:
                    break
                }
                return .none

            case .replaceConfirmed:
                return .send(.nextTapped)

            case .replaceCancelled:
                state.isConfirmingReplace = false
                return .none

            case let .saved(success):
                state.isSaving = false
                state.saveFailed = !success
                state.isSaved = success
                return success ? .send(.delegate(.finished)) : .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$dataSources, action: \.dataSources) { DataSourcesFeature() }
        .ifLet(\.$changeBuses, action: \.changeBuses) { ChangeBusesFeature() }
    }

    private func updateSchool(_ state: inout State, _ change: (inout SchoolForm) -> Void) {
        guard let id = state.tabKid?.id, var school = state.kids[id: id]?.school else { return }
        change(&school)
        state.kids[id: id]?.school = school
    }

    private func updateGoing(_ state: inout State, _ change: (inout GoingForm) -> Void) {
        guard let id = state.goingKid?.id, var going = state.kids[id: id]?.going else { return }
        change(&going)
        state.kids[id: id]?.going = going
    }
}

extension KidEntry {
    /// The kid as "Start" saves them. A face not picked stays empty: the colour dot shows instead.
    var kid: Kid {
        let form = self.school
        let school: School? = goesOut ? form.name.map { name in
            let preschool = form.kind == .preschool
            // Per-weekday hours as the school website states them, while the grown-up kept them.
            let dayHours = form.websiteDays.values.filter { form.days.contains($0.weekday) }
                .sorted { $0.weekday < $1.weekday }
            return School(name: name, days: form.days, start: form.start ?? 0, end: form.end ?? 0,
                          directoryID: preschool ? nil : form.picked?.id, usesMoeTerms: preschool ? nil : form.usesMoeTerms,
                          arriveBy: preschool ? form.start : form.arriveBy, latest: preschool ? nil : form.latest,
                          kind: form.kind, dayHours: dayHours.isEmpty ? nil : dayHours)
        } : nil
        return Kid(id: id, name: trimmedName, colorIndex: colorIndex, age: age ?? 0, schoolYear: nil, school: school,
                   face: face ?? "")
    }

    /// By bus with a known stop: the C2 plan. Its "Late" mirrors the school record's grace.
    var busPlan: BusPlan? {
        guard going.way == .bus, going.search.stop.count == 5 else { return nil }
        return BusPlan(kid: id, stop: going.search.stop, services: going.services, walk: going.walk, ride: going.ride,
                       lateGrace: kid.school?.lateGrace ?? BusPlan.defaultLateGrace,
                       rides: going.rides.filter { going.services.contains($0.key) }, changes: going.changes)
    }
}

extension SetupFeature {
    static func remove(_ id: KidEntry.ID, from state: inout State) {
        guard state.kids.count >= 2 else { return }
        state.kids.remove(id: id)
        if state.schoolTab == id, let first = state.kids.first { state.schoolTab = first.id }
    }
}
