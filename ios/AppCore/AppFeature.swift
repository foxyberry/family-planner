import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Grownup
import Home
import Missions
import ParentAuthClient
import Strings
import SwiftUI

/// Root of the app. Lifecycle events arrive here as actions so they can be tested
/// like any other feature; the app target only forwards them.
@Reducer
public struct AppFeature {
    @Reducer
    public enum Path {
        case hub(GrownupHubFeature)
        case editor(ItemEditorFeature)
        case ourDay(OurDayFeature)
        case missionEditor(MissionEditorFeature)
        case busSettings(BusSettingsFeature)
        case gallery(GalleryFeature)
        /// A2 · Morning, pushed over home (user, 2026-11-09: push, not a cover). A kid screen: the
        /// grown-up rules (idle lock, app-switcher cover) skip it.
        case missions(MissionsFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var now: Date?
        public var scenePhase: ScenePhase = .inactive
        public var path = StackState<Path.State>()
        public var home = HomeFeature.State()
        /// The grown-up lock over the home screen (board C0), `nil` when it is closed.
        public var lock: LockOverlay.State?
        /// Real seconds since a grown-up last touched a grown-up screen (`nil` on the home screen);
        /// grown-up screens close at 120. Counted in 1-second ticks, not from the date, so a clock
        /// change (or the developer time machine) never closes them early.
        public var grownupIdleSeconds: Int?
        /// "Locks in 0:30" during the last 30 seconds, shown instead of "Grown-ups only".
        public var relockCaption: String?
        /// A debug link's grown-up board, opened once the unlock passes and the hub has loaded.
        public var pendingBoard: GrownupBoard?

        public init() {}

        /// Set when the app stops being active with grown-up screens open; cleared only once it is
        /// active again, so the cover outlasts the relock that empties `path` during backgrounding.
        public var coverUntilActive = false

        /// Grown-up screens are hidden whenever the app is not active, so the app-switcher snapshot
        /// and brief interruptions (Control Center) never show them to a child.
        public var coversGrownupScreens: Bool { scenePhase != .active && (coverUntilActive || hasGrownupScreens) }

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

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date
    @Dependency(\.parentAuth) var parentAuth

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

            case .task:
                return .run { [clock, date] send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.tick(date.now))
                    }
                }

            case let .tick(now):
                state.now = now
                if state.hasGrownupScreens, let seconds = state.grownupIdleSeconds {
                    let idle = seconds + 1
                    state.grownupIdleSeconds = idle
                    if idle >= Self.idleLimit {
                        relock(&state)
                    } else if idle >= Self.idleLimit - Self.countdown {
                        state.relockCaption = L10n.tr("relock.countdown", Self.idleLimit - idle)
                    } else {
                        state.relockCaption = nil
                    }
                }
                return .send(.home(.tick(now)))

            case let .linkOpened(link):
                // A link leaves open grown-up screens locked again; a grown-up board asks again.
                if state.hasGrownupScreens { relock(&state) }
                switch link {
                case .home:
                    state.path.removeAll()
                case .missions:
                    if !state.isShowingMissions { state.path.append(.missions(MissionsFeature.State())) }
                case let .grownup(board):
                    // The usual unlock, as after the hold; the board opens once the hub has loaded.
                    state.path.removeAll()
                    state.pendingBoard = board
                    state.lock = .scanning
                    return authenticate()
                }
                return .none

            case let .path(.element(id: id, action: .hub(.loaded(snapshot)))):
                guard let board = state.pendingBoard else { return .none }
                state.pendingBoard = nil
                let hub = { (action: GrownupHubFeature.Action) in
                    Effect<Action>.send(.path(.element(id: id, action: .hub(action))))
                }
                switch board {
                case .c1: return .none
                case .e6: return snapshot?.kids.dropFirst().first.map { hub(.kidTabTapped($0.id)) } ?? .none
                case .c2: return hub(.busesRowTapped)
                case .c3: return hub(.addWeeklyTapped)
                case .c4: return hub(.addOnceTapped)
                case .c5: return hub(.missionsRowTapped)
                case .c6: return hub(.dayRowTapped)
                }

            case .home(.missionsTapped):
                if !state.isShowingMissions { state.path.append(.missions(MissionsFeature.State())) }
                return .none

            case let .path(.element(id: id, action: .missions(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case .home(.clockHoldCompleted):
                state.lock = .scanning
                return authenticate()

            case .parentAuthResponse(.success):
                openGrownupScreens(&state)
                return .none

            case .parentAuthResponse(.notRecognised):
                state.lock = .notRecognised
                return .none

            case .parentAuthResponse(.cancelled):
                state.lock = nil
                state.pendingBoard = nil
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
                return .none

            case .grownupTouched:
                state.grownupIdleSeconds = 0
                state.relockCaption = nil
                return .none

            case .path(.element(id: _, action: .hub(.backTapped))):
                state.path.removeAll()
                state.grownupIdleSeconds = nil
                state.relockCaption = nil
                return .none

            case let .path(.element(id: id, action: .hub(.addWeeklyTapped))),
                 let .path(.element(id: id, action: .hub(.addOnceTapped))):
                guard case let .hub(hub) = state.path[id: id], let kid = hub.selectedKid else { return .none }
                let repeats: ItemForm.Repeat = if case .path(.element(_, .hub(.addOnceTapped))) = action { .once } else { .weekly }
                state.path.append(.editor(ItemEditorFeature.State(mode: .add(.kid(kid)), repeats: repeats,
                                                                  now: date.now, calendar: calendar)))
                return .none

            case let .path(.element(id: id, action: .hub(.onceItemTapped(itemID)))),
                 let .path(.element(id: id, action: .hub(.weeklyItemTapped(itemID)))):
                guard case let .hub(hub) = state.path[id: id],
                      let item = hub.snapshot?.items.first(where: { $0.id == itemID }) else { return .none }
                let mode: ItemEditorFeature.Mode = item.isWeekly ? .editWeekly(item) : .editOnce(item)
                state.path.append(.editor(ItemEditorFeature.State(mode: mode, now: date.now, calendar: calendar)))
                return .none

            case let .path(.element(id: id, action: .hub(.dayRowTapped))):
                guard case let .hub(hub) = state.path[id: id], let kid = hub.selectedKid else { return .none }
                state.path.append(.ourDay(OurDayFeature.State(kid: kid, today: Day(date.now, calendar: calendar),
                                                              calendar: calendar)))
                return .none

            case let .path(.element(id: id, action: .hub(.missionsRowTapped))):
                guard case let .hub(hub) = state.path[id: id], let kid = hub.selectedKid else { return .none }
                state.path.append(.missionEditor(MissionEditorFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: id, action: .missionEditor(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: id, action: .hub(.busesRowTapped))):
                guard case let .hub(hub) = state.path[id: id], let kid = hub.selectedKid else { return .none }
                state.path.append(.busSettings(BusSettingsFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: id, action: .busSettings(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: id, action: .ourDay(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: _, action: .editor(.delegate(.openBuses(kid))))):
                state.path.append(.busSettings(BusSettingsFeature.State(kid: kid)))
                return .none

            case let .path(.element(id: id, action: .editor(.delegate(.finished)))):
                state.path.pop(from: id)
                return .none

            case let .path(.element(id: id, action: .gallery(.backTapped))):
                state.path.pop(from: id)
                return .none

            case .path(.element(id: _, action: .hub(.galleryButtonTapped))):
                state.path.append(.gallery(GalleryFeature.State()))
                return .none

            case .path, .home:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    private func authenticate() -> Effect<Action> {
        .run { [parentAuth] send in
            await send(.parentAuthResponse(parentAuth.authenticate(L10n.tr("auth.reason"))))
        }
    }

    private func openGrownupScreens(_ state: inout State) {
        state.lock = nil
        state.grownupIdleSeconds = 0
        state.path.append(.hub(GrownupHubFeature.State()))
    }

    /// Back to the home screen; the next grown-up screen needs Face ID again. Unsaved forms are dropped.
    private func relock(_ state: inout State) {
        // Grown-up screens close; a morning screen on its own stays (it is a kid screen).
        if state.hasGrownupScreens { state.path.removeAll() }
        state.grownupIdleSeconds = nil
        state.relockCaption = nil
        state.lock = nil
        state.pendingBoard = nil
    }
}

extension AppFeature.Path.State: Equatable {}
