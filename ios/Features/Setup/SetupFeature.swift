import ComposableArchitecture
import Domain
import Foundation
import Grownup
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
        /// S3 for the kid at this index of `goingKids`.
        case gettingThere(Int)
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
    public struct State: Equatable {
        public static let mostKids = 4

        public var step: Step = .family
        public var kids: IdentifiedArrayOf<KidEntry>
        /// S2's kid tab.
        public var schoolTab: KidEntry.ID
        /// The bundled school lists, loaded once.
        public var directory: [SchoolEntry] = []
        public var isSaving = false
        public var saveFailed = false
        /// Start worked; setup is closing and never saves again.
        public var isSaved = false
        /// A debug link opened setup over an existing family: Start asks before replacing it.
        public var replacesFamily = false
        public var isConfirmingReplace = false
        /// S1: the kid whose × asks "Remove {name}?" (a card with something typed asks first).
        public var removeConfirm: KidEntry.ID?

        /// S1 (layout v13): every card has a × while there are two or more.
        public var canRemoveKids: Bool { kids.count >= 2 }
        /// Data sources (spec S2), opened from the link under the school caption.
        @Presents public var dataSources: DataSourcesFeature.State?
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
            guard case let .gettingThere(index) = step, goingKids.indices.contains(index) else { return nil }
            return goingKids[index]
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
            case .gettingThere: true
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
        case wayPicked(Way)
        case stopSearch(StopSearchFeature.Action)
        case serviceTapped(String)
        case walkChanged(Int)
        case rideChanged(Int)
        case leaveChanged(Int)
        // S4
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
                guard state.directory.isEmpty else { return .none }
                return .run { [schoolDirectory] send in await send(.directoryLoaded(await schoolDirectory.schools())) }

            case let .directoryLoaded(schools):
                state.directory = schools
                return .none

            case .backTapped:
                switch state.step {
                case .family: break
                case .school: state.step = .family
                case let .gettingThere(index): state.step = index > 0 ? .gettingThere(index - 1) : .school
                case .almostDone:
                    let count = state.goingKids.count
                    state.step = count > 0 ? .gettingThere(count - 1) : .school
                }
                return .none

            case .nextTapped:
                guard state.canGoNext else { return .none }
                switch state.step {
                case .family:
                    state.step = .school
                    if state.kids[id: state.schoolTab] == nil, let first = state.kids.first { state.schoolTab = first.id }
                case .school:
                    state.step = state.goingKids.isEmpty ? .almostDone : .gettingThere(0)
                case let .gettingThere(index):
                    state.step = index + 1 < state.goingKids.count ? .gettingThere(index + 1) : .almostDone
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
                    return .run { [scheduleStore] send in
                        do {
                            try await scheduleStore.replaceFamily(family)
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
                    // Hours from the school's own website; Latest = the start + 10 minutes.
                    school.start = entry.hours?.start
                    school.end = entry.hours?.end
                    school.arriveBy = entry.hours?.start
                    school.latest = entry.hours.map { $0.start + 10 }
                    school.hoursSource = source
                    school.websiteDays = entry.hours?.byWeekday ?? [:]
                }
                return .none

            case .notInListTapped:
                updateSchool(&state) { school in
                    school.typedByHand = true
                    school.picked = nil
                    school.matches = []
                    school.start = nil
                    school.end = nil
                    school.arriveBy = nil
                    school.latest = nil
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

            case let .wayPicked(way):
                updateGoing(&state) { $0.way = way }
                return .none

            case .stopSearch(.textChanged):
                // A new stop: the buses picked for the old one no longer apply.
                updateGoing(&state) { $0.services = [] }
                return .none

            case .stopSearch:
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
                updateGoing(&state) { going in
                    if let index = going.services.firstIndex(of: service) {
                        going.services.remove(at: index)
                    } else {
                        going.services.append(service)
                    }
                }
                return .none

            case let .walkChanged(value):
                updateGoing(&state) { $0.walk = min(max(value, 0), 60) }
                return .none

            case let .rideChanged(value):
                updateGoing(&state) { $0.ride = min(max(value, 0), 90) }
                return .none

            case let .leaveChanged(value):
                updateGoing(&state) { $0.leaveBefore = min(max(value, 0), 90) }
                return .none

            // MARK: S4

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

    /// By bus with a known stop: the C2 plan. Its "Late up to" mirrors the school record's grace.
    var busPlan: BusPlan? {
        guard going.way == .bus, going.search.stop.count == 5 else { return nil }
        return BusPlan(kid: id, stop: going.search.stop, services: going.services, walk: going.walk, ride: going.ride,
                       lateGrace: kid.school?.lateGrace ?? BusPlan.defaultLateGrace)
    }
}

extension SetupFeature {
    static func remove(_ id: KidEntry.ID, from state: inout State) {
        guard state.kids.count >= 2 else { return }
        state.kids.remove(id: id)
        if state.schoolTab == id, let first = state.kids.first { state.schoolTab = first.id }
    }
}
