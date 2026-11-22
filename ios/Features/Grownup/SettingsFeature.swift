import AppSettings
import ComposableArchitecture
import Domain
import Foundation
import Localization
import ParentAuthClient
import ScheduleStore
import SchoolDirectory
import Strings

/// Settings (board G6, replaces C1 "Our kids"): a tab per kid with About, School, Getting there and
/// Routines, and a Family tab with this iPad's switches. It opens over Our day; back returns there.
@Reducer
public struct SettingsFeature {
    /// A kid's tab or the Family tab.
    public enum Tab: Hashable, Sendable {
        case kid(Kid.ID)
        case family
    }

    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var tab: Tab?
        public var snapshot: ScheduleSnapshot?
        /// The kids' school calendars (Terms).
        public var schools: [Kid.ID: SchoolCalendar] = [:]
        public var settings = AppSettings.defaults
        /// Turning the lock on checks Face ID first (as on S4); a failed check says so.
        public var isCheckingLock = false
        public var lockNeedsFaceID = false
        /// This iPad has Touch ID (the lock row names it).
        public var isTouchID = false
        public var today: Day?
        /// The day the bundled school lists were made (the foot's "School lists · 9 Nov").
        public var listsUpdated: Day?
        /// Replaced by the `\.calendar` dependency on `.task`, together with `today`.
        public var calendar = Calendar(identifier: .gregorian)

        /// `kid`: the tab to open on (Settings from Our day opens on the kid shown there).
        public init(kid: Kid.ID? = nil) {
            tab = kid.map(Tab.kid)
        }

        public var selectedKid: Kid.ID? { if case let .kid(id)? = tab { id } else { nil } }
        public var kid: Kid? { snapshot?.kids.first { $0.id == selectedKid } }

        /// The header's tabs: each kid, then "Family".
        public var tabs: [(Tab, String, Kid?)] {
            (snapshot?.kids ?? []).map { (Tab.kid($0.id), $0.name, $0) } + [(.family, "", nil)]
        }

        /// The kid tab's sections (board G6).
        public var sections: [SettingsSection] {
            guard let kid, let snapshot, let today else { return [] }
            return SettingsModel.sections(kid: kid, missions: snapshot.missions,
                                          busPlan: snapshot.busPlans.route(kid: kid.id),
                                          schoolYear: schools[kid.id] ?? .none, today: today, calendar: calendar,
                                          routines: snapshot.routines)
        }

        /// Board G6f "Children": one row per kid, "{age} · {place}".
        public var childRows: [(kid: Kid, detail: String)] {
            (snapshot?.kids ?? []).map { kid in
                (kid, L10n.tr("settings.child.detail", kid.age, kid.school?.name ?? L10n.tr("settings.child.home")))
            }
        }
        /// "+ Add a child", up to four kids.
        /// Board G6 / G6f foot: "School lists · 9 Nov" over "Data sources".
        public var listsLine: String? {
            listsUpdated.map { L10n.tr("settings.lists", DayText.dayMonth($0, calendar: calendar)) }
        }
        public var canAddChild: Bool { (snapshot?.kids.count ?? 0) < AddChildFeature.most }

        /// The Family tab's switches (the same rows as S4).
        public var settingRows: [AppSettingRow] { settings.rows(lockNeedsFaceID: lockNeedsFaceID, touchID: isTouchID) }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?, schools: [Kid.ID: SchoolCalendar])
        case listsLoaded(Day?)
        case tabTapped(Tab)
        case settingTapped(AppSetting)
        case lockChecked(ParentAuthOutcome)
        /// Navigation the app's stack handles.
        case missionsRowTapped
        case busesRowTapped
        /// School, Hours and Terms open G4.
        case schoolRowTapped
        /// A kid at home: the School row opens G7.
        case changeSchoolRowTapped
        /// "From {d Mon}" under Hours: G4 on the waiting hours change.
        case waitingHoursRowTapped
        /// Board G6f: a Children row opens that kid's tab; "+ Add a child" opens the kid card.
        case childTapped(Kid.ID)
        case addChildTapped
        case backTapped
        /// "Data sources": the open-data notices the school list's licences ask for.
        case dataSourcesTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// The grown-up lock was turned on or off: the app's gate follows it at once.
            case grownupLockChanged(Bool)
            case addChild
        }
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.appSettings) var appSettings
    @Dependency(\.parentAuth) var parentAuth

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isTouchID = parentAuth.biometry() == .touchID
                state.calendar = calendar
                state.today = Day(date.now, calendar: calendar)
                state.settings = appSettings.load()
                return .run { [scheduleStore, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: [])
                    await send(.loaded(snapshot, schools: family.schools))
                    await send(.listsLoaded(await schoolDirectory.updated()))
                }

            case let .listsLoaded(day):
                state.listsUpdated = day
                return .none

            case let .loaded(snapshot, schools):
                state.snapshot = snapshot
                state.schools = schools
                let kids = snapshot?.kids ?? []
                if state.tab == nil || (state.selectedKid != nil && !kids.contains { $0.id == state.selectedKid }) {
                    state.tab = kids.first.map { .kid($0.id) } ?? .family
                }
                return .none

            case let .tabTapped(tab):
                state.tab = tab
                return .none

            case let .settingTapped(setting):
                // This iPad's switches save at once. The lock turns off at once; on checks Face ID
                // first (spec "S4 · Almost done").
                switch setting {
                case .grownupLock:
                    guard !state.isCheckingLock else { return .none }
                    guard !state.settings.grownupLock else {
                        state.settings.grownupLock = false
                        appSettings.save(state.settings)
                        return .send(.delegate(.grownupLockChanged(false)))
                    }
                    state.isCheckingLock = true
                    return .run { [parentAuth] send in
                        await send(.lockChecked(parentAuth.authenticate(L10n.tr("auth.reason"))))
                    }
                case .medals: state.settings.medals.toggle()
                }
                appSettings.save(state.settings)
                return .none

            case let .lockChecked(outcome):
                state.isCheckingLock = false
                switch outcome {
                case .success:
                    state.settings.grownupLock = true
                    state.lockNeedsFaceID = false
                    appSettings.save(state.settings)
                    return .send(.delegate(.grownupLockChanged(true)))
                case .notAvailable, .notRecognised, .lockedOut:
                    state.lockNeedsFaceID = true
                case .cancelled:
                    break
                }
                return .none

            case let .childTapped(kid):
                return .send(.tabTapped(.kid(kid)))

            case .addChildTapped:
                return .send(.delegate(.addChild))

            case .missionsRowTapped, .busesRowTapped, .schoolRowTapped, .changeSchoolRowTapped, .waitingHoursRowTapped, .backTapped, .dataSourcesTapped, .delegate:
                return .none
            }
        }
    }
}
