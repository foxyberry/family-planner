import AppSettings
import ComposableArchitecture
import DesignSystem
import DeviceLook
import Domain
import Foundation
import Grownup
import Home
import Missions
import ParentAuthClient
import ScheduleStore
import Setup
import Strings
import SwiftUI

/// Root of the app. Lifecycle events arrive here as actions so they can be tested
/// like any other feature; the app target only forwards them.
@Reducer
public struct AppFeature {
    @Reducer
    public enum Path {
        case settings(SettingsFeature)
        case editor(ItemEditorFeature)
        case ourDay(OurDayFeature)
        case missionEditor(MissionEditorFeature)
        case busSettings(BusSettingsFeature)
        case dataSources(DataSourcesFeature)
        /// A2 · Morning, pushed over home (user, 2026-11-09: push, not a cover). A kid screen: the
        /// grown-up rules (idle lock, app-switcher cover) skip it.
        case missions(MissionsFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var now: Date?
        public var scenePhase: ScenePhase = .inactive
        public var path = StackState<Path.State>()

        /// The iPad's own light or dark setting, read every second (`deviceLook`).
        public var deviceIsDark = false
        /// The window's colour scheme (spec "Night mapping"): the iPad's own while grown-up screens
        /// are open, light for setup, else the home's look (the kid home and A2). Always a value:
        /// going from dark back to nil (follow the system) kept the window dark on the iPad.
        public var colorScheme: ColorScheme {
            guard setup == nil else { return .light }
            if hasGrownupScreens { return deviceIsDark ? .dark : .light }
            return home.look == .night ? .dark : .light
        }
        public var home = HomeFeature.State()
        /// The grown-up lock over the home screen (board C0), `nil` when it is closed.
        public var lock: LockOverlay.State?
        /// Real seconds since a grown-up last touched a grown-up screen (`nil` on the home screen);
        /// grown-up screens close at 120. Counted in 1-second ticks, not from the date, so a clock
        /// change (or the developer time machine) never closes them early.
        public var grownupIdleSeconds: Int?
        /// "Locks in 0:30" during the last 30 seconds, shown instead of "Grown-ups only".
        public var relockCaption: String?
        /// A debug link's grown-up board, opened once the unlock passes and Our day has loaded.
        public var pendingBoard: GrownupBoard?
        /// Grown-up mode was asked for before the home had loaded its kids (a link at launch with
        /// the lock off); Our day opens as soon as they are known.
        public var opensGrownupOnHomeLoad = false
        /// Whether this iPad has a family yet; nil until the store has been read at launch.
        public var hasFamily: Bool?
        /// First-run setup (S1–S4) instead of the home, while the iPad has no family.
        public var setup: SetupFeature.State?
        /// S4 "Grown-up lock" (layout v17). Off: the 2 s hold is the only gate, no Face ID and no
        /// app-switcher cover; the 2-minute return home stays.
        public var grownupLock = true

        public init() {}

        /// Set when the app stops being active with grown-up screens open; cleared only once it is
        /// active again, so the cover outlasts the relock that empties `path` during backgrounding.
        public var coverUntilActive = false

        /// Grown-up screens are hidden whenever the app is not active, so the app-switcher snapshot
        /// and brief interruptions (Control Center) never show them to a child.
        public var coversGrownupScreens: Bool {
            grownupLock && scenePhase != .active && (coverUntilActive || hasGrownupScreens)
        }

        /// The morning screen is on the stack (pushed from home or by its link).
        public var isShowingMissions: Bool {
            if case .missions? = path.first { true } else { false }
        }

        /// A grown-up screen is open: the stack holds something other than the morning screen.
        public var hasGrownupScreens: Bool {
            path.contains { if case .missions = $0 { false } else { true } }
        }
    }

    public enum AppDelegateAction: Equatable {
        case didFinishLaunching
    }

    public enum Action {
        case appDelegate(AppDelegateAction)
        case scenePhaseChanged(ScenePhase)
        case task
        /// Reads the store once at launch: no kids means first-run setup.
        case checkFamily
        case familyChecked(hasFamily: Bool)
        /// The debug tools replaced the stored family ("Load sample family").
        case familyReplaced
        case setup(SetupFeature.Action)
        case tick(Date)
        case parentAuthResponse(ParentAuthOutcome)
        case lockPrimaryTapped
        case lockCancelTapped
        case grownupTouched
        case path(StackActionOf<Path>)
        case home(HomeFeature.Action)
        /// A screen deep link (`familyplanner://missions`).
        case linkOpened(ScreenLink)
    }

    @Dependency(\.deviceLook) var deviceLook
    @Dependency(\.appSettings) var appSettings
    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date
    @Dependency(\.parentAuth) var parentAuth
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.uuid) var uuid

    /// Grown-up screens close after this many seconds without a touch.
    static let idleLimit = 120
    /// The countdown caption shows for this many seconds before they close.
    static let countdown = 30

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) { HomeFeature() }
        // Working in a grown-up screen (typing, picking, saving) keeps it open: the keyboard is a separate
        // window, so the touch gesture never sees typing.
        Reduce { state, action in
            if case .path(.element) = action, state.hasGrownupScreens {
                state.grownupIdleSeconds = 0
                state.relockCaption = nil
            }
            return .none
        }
        Reduce { state, action in
            switch action {
            case .appDelegate(.didFinishLaunching):
                // Start-up work (notification permission, background tasks) will hang off here.
                return .none

            case let .scenePhaseChanged(phase):
                state.scenePhase = phase
                if phase == .active {
                    state.coverUntilActive = false
                } else if state.hasGrownupScreens {
                    state.coverUntilActive = true
                }
                if phase == .background { relock(&state) }
                return .none

            case .checkFamily:
                state.grownupLock = appSettings.load().grownupLock
                return .run { [scheduleStore] send in
                    // An unreadable store is not an empty one: setup would replace it, so it never opens then.
                    guard let snapshot = try? await scheduleStore.load() else { return }
                    await send(.familyChecked(hasFamily: !snapshot.kids.isEmpty))
                }

            case let .familyChecked(hasFamily):
                state.hasFamily = hasFamily
                if !hasFamily, state.setup == nil {
                    state.setup = SetupFeature.State(firstKid: uuid(), calendar: calendar)
                }
                return .none

            case .setup(.delegate(.finished)):
                state.setup = nil
                state.hasFamily = true
                state.grownupLock = appSettings.load().grownupLock
                return .send(.home(.reload))

            case .setup:
                return .none

            case .familyReplaced:
                state.path.removeAll()
                relock(&state)
                state.setup = nil
                state.hasFamily = true
                return .send(.home(.reload))

            case .task:
                return .run { [clock, date] send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.tick(date.now))
                    }
                }

            case let .tick(now):
                state.now = now
                state.deviceIsDark = deviceLook.isDark()
                if state.hasGrownupScreens, let seconds = state.grownupIdleSeconds {
                    let idle = seconds + 1
                    state.grownupIdleSeconds = idle
                    if idle >= Self.idleLimit {
                        relock(&state)
                    } else if idle >= Self.idleLimit - Self.countdown {
                        // With the lock off nothing locks: the screens only go home.
                        let left = Self.idleLimit - idle
                        state.relockCaption = state.grownupLock ? L10n.tr("relock.countdown", left)
                            : L10n.tr("relock.countdown.home", left)
                    } else {
                        state.relockCaption = nil
                    }
                }
                return .send(.home(.tick(now)))

            case let .linkOpened(link):
                // A link at launch can come before `.checkFamily`: read the lock setting now, so a
                // lock that is off is not taken for the default (on).
                state.grownupLock = appSettings.load().grownupLock
                // A link leaves open grown-up screens locked again; a grown-up board asks again.
                if state.hasGrownupScreens || state.opensGrownupOnHomeLoad { relock(&state) }
                switch link {
                case .home:
                    state.path.removeAll()
                case .missions:
                    if !state.isShowingMissions { state.path.append(.missions(MissionsFeature.State(look: state.home.look))) }
                case let .grownup(board):
                    // The usual unlock, as after the hold; the board opens once Our day has loaded.
                    state.path.removeAll()
                    state.pendingBoard = board
                    return unlock(&state)
                case let .setup(step):
                    // Debug builds only. No unlock: setup has no grown-up lock, and nothing is
                    // saved until Start on S4.
                    #if DEBUG
                    state.path.removeAll()
                    var setup = SetupFeature.State.sample(step: step, calendar: calendar)
                    // Over a family, Start asks before replacing it (spec S1–S4 "Debug only").
                    setup.replacesFamily = state.hasFamily != false
                    state.setup = setup
                    #else
                    _ = step
                    #endif
                    return .none
                }
                return .none

            case let .path(.element(id: _, action: .ourDay(.loaded(snapshot, _)))),
                 let .path(.element(id: _, action: .settings(.loaded(snapshot, _)))):
                // A grown-up debug link opens its board over Our day once the family is known.
                guard let board = state.pendingBoard, let kids = snapshot?.kids, let first = kids.first else { return .none }
                state.pendingBoard = nil
                openBoard(board, kids: kids, first: first, &state)
                return .none

            case .path(.element(id: _, action: .ourDay(.delegate(.finished)))):
                state.path.removeAll()
                state.grownupIdleSeconds = nil
                state.relockCaption = nil
                return .none

            case let .path(.element(id: _, action: .ourDay(.delegate(.openSettings(kid))))):
                state.path.append(.settings(SettingsFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: _, action: .ourDay(.delegate(.add(kid, repeats))))):
                state.path.append(.editor(ItemEditorFeature.State(mode: .add(.kid(kid)), repeats: repeats,
                                                                  now: date.now, calendar: calendar)))
                return .none

            case let .path(.element(id: id, action: .ourDay(.delegate(.openItem(itemID))))):
                guard case let .ourDay(day) = state.path[id: id],
                      let item = day.items.first(where: { $0.id == itemID }) else { return .none }
                let mode: ItemEditorFeature.Mode = item.isWeekly ? .editWeekly(item) : .editOnce(item)
                state.path.append(.editor(ItemEditorFeature.State(mode: mode, now: date.now, calendar: calendar)))
                return .none

            case .home(.missionsTapped):
                if !state.isShowingMissions { state.path.append(.missions(MissionsFeature.State(look: state.home.look))) }
                return .none

            case let .path(.element(id: id, action: .missions(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case .home(.clockHoldCompleted), .home(.pencilTapped):
                return unlock(&state)

            case .home(.tick), .home(.skySwitchTapped):
                // A2 after dusk takes the night look with the home (board A2 night).
                for id in state.path.ids {
                    if case var .missions(missions) = state.path[id: id], missions.look != state.home.look {
                        missions.look = state.home.look
                        state.path[id: id] = .missions(missions)
                    }
                }
                return .none

            case .home(.loaded):
                // The home's kids are known now (Scope ran first), so a waiting Our day can open.
                if state.opensGrownupOnHomeLoad, !state.home.days.isEmpty {
                    state.opensGrownupOnHomeLoad = false
                    openGrownupScreens(&state)
                }
                return .none

            case .parentAuthResponse(.success):
                openGrownupScreens(&state)
                return .none

            case .parentAuthResponse(.notRecognised):
                state.lock = .notRecognised
                return .none

            case .parentAuthResponse(.cancelled):
                state.lock = nil
                state.pendingBoard = nil
                state.opensGrownupOnHomeLoad = false
                return .none

            case .parentAuthResponse(.notAvailable):
                state.lock = .notAvailable(touchID: parentAuth.biometry() == .touchID)
                return .none

            case .parentAuthResponse(.lockedOut):
                state.lock = .lockedOut
                return .none

            case .lockPrimaryTapped:
                switch state.lock {
                case .notRecognised:
                    state.lock = .scanning
                    return authenticate()
                case .notAvailable:
                    // No Face ID on this iPad: the 2-second hold was the gate.
                    openGrownupScreens(&state)
                    return .none
                default:
                    return .none
                }

            case .lockCancelTapped:
                state.lock = nil
                state.pendingBoard = nil
                state.opensGrownupOnHomeLoad = false
                return .none

            case .grownupTouched:
                state.grownupIdleSeconds = 0
                state.relockCaption = nil
                return .none

            case let .path(.element(id: _, action: .settings(.delegate(.grownupLockChanged(on))))):
                // Settings saved the lock: the Face ID gate and the app-switcher cover follow it now,
                // not only after the next launch.
                state.grownupLock = on
                return .none

            case let .path(.element(id: id, action: .settings(.backTapped))):
                // Settings sits over Our day (board G6): back returns to the clock.
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: id, action: .settings(.missionsRowTapped))):
                guard case let .settings(settings) = state.path[id: id], let kid = settings.selectedKid else { return .none }
                state.path.append(.missionEditor(MissionEditorFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: id, action: .missionEditor(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: id, action: .settings(.busesRowTapped))):
                guard case let .settings(settings) = state.path[id: id], let kid = settings.selectedKid else { return .none }
                state.path.append(.busSettings(BusSettingsFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: id, action: .busSettings(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: _, action: .editor(.delegate(.openBuses(kid))))):
                state.path.append(.busSettings(BusSettingsFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: id, action: .editor(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case .path(.element(id: _, action: .settings(.dataSourcesTapped))):
                state.path.append(.dataSources(DataSourcesFeature.State()))
                return .none

            case let .path(.element(id: id, action: .dataSources(.backTapped))):
                state.path.pop(from: id)
                return .none

            case .path, .home:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.setup, action: \.setup) { SetupFeature() }
    }

    /// After the hold (or a grown-up link): Face ID, or straight in while the lock is off.
    private func unlock(_ state: inout State) -> Effect<Action> {
        guard state.grownupLock else {
            openGrownupScreens(&state)
            return .none
        }
        state.lock = .scanning
        return authenticate()
    }

    private func authenticate() -> Effect<Action> {
        .run { [parentAuth] send in
            await send(.parentAuthResponse(parentAuth.authenticate(L10n.tr("auth.reason"))))
        }
    }

    /// A debug link's board over Our day (or over Settings when no home was loaded yet).
    private func openBoard(_ board: GrownupBoard, kids: [Kid], first: Kid, _ state: inout State) {
        switch board {
        case .c6:
            break
        case .c1:
            if case .settings? = state.path.last { break }
            state.path.append(.settings(SettingsFeature.State(kid: first.id)))
        case .e6:
            let second = kids.dropFirst().first?.id ?? first.id
            if case var .settings(settings)? = state.path.last, let id = state.path.ids.last {
                settings.tab = .kid(second)
                state.path[id: id] = .settings(settings)
            } else {
                state.path.append(.settings(SettingsFeature.State(kid: second)))
            }
        case .c2:
            state.path.append(.busSettings(BusSettingsFeature.State(kid: first.id)))
        case .c3, .c4:
            state.path.append(.editor(ItemEditorFeature.State(mode: .add(.kid(first.id)), repeats: board == .c3 ? .weekly : .once,
                                                              now: date.now, calendar: calendar)))
        case .c5:
            state.path.append(.missionEditor(MissionEditorFeature.State(kid: first.id)))
        }
    }

    /// Grown-up mode opens on the day on the clock (board G1) for the first kid.
    private func openGrownupScreens(_ state: inout State) {
        // The first frame already in the iPad's own look, not a second later.
        state.deviceIsDark = deviceLook.isDark()
        state.lock = nil
        state.grownupIdleSeconds = 0
        guard let kid = state.home.days.first?.kid.id else {
            // Not loaded yet: wait for the home rather than open Settings in place of Our day.
            if state.hasFamily == true {
                state.opensGrownupOnHomeLoad = true
                return
            }
            state.path.append(.settings(SettingsFeature.State()))
            return
        }
        state.path.append(.ourDay(OurDayFeature.State(kid: kid, today: Day(date.now, calendar: calendar),
                                                      calendar: calendar)))
    }

    /// Back to the home screen; the next grown-up screen needs Face ID again. Unsaved forms are dropped.
    private func relock(_ state: inout State) {
        // Grown-up screens close; a morning screen on its own stays (it is a kid screen).
        if state.hasGrownupScreens { state.path.removeAll() }
        state.grownupIdleSeconds = nil
        state.relockCaption = nil
        state.lock = nil
        state.pendingBoard = nil
        // A grown-up open still waiting for the home never survives a relock (it passed the old gate).
        state.opensGrownupOnHomeLoad = false
    }
}

extension AppFeature.Path.State: Equatable {}
