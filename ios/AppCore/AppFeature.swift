import ComposableArchitecture
import DesignSystem
import Foundation
import Grownup
import Home
import ParentAuthClient
import SwiftUI
import UIKit

/// Root of the app. Lifecycle events arrive here as actions so they can be tested
/// like any other feature; the app target only forwards them.
@Reducer
public struct AppFeature {
    @Reducer
    public enum Path {
        case hub(GrownupHubFeature)
        case editor(ItemEditorFeature)
        case gallery(GalleryFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var now: Date?
        public var scenePhase: ScenePhase = .inactive
        public var path = StackState<Path.State>()
        public var home = HomeFeature.State()
        /// The grown-up lock over the home screen (board C0), `nil` when it is closed.
        public var lock: LockOverlay.State?
        /// When a grown-up last touched a grown-up screen; grown-up screens close 2 minutes after it.
        public var lastGrownupTouch: Date?
        /// "Locks in 0:30" during the last 30 seconds, shown instead of "Grown-ups only".
        public var relockCaption: String?

        public init() {}

        /// Grown-up screens are hidden whenever the app is not active, so the app-switcher snapshot
        /// and brief interruptions (Control Center) never show them to a child.
        public var coversGrownupScreens: Bool { scenePhase != .active && !path.isEmpty }
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
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date
    @Dependency(\.parentAuth) var parentAuth
    @Dependency(\.openURL) var openURL

    /// Grown-up screens close after this long without a touch.
    static let idleLimit: TimeInterval = 120
    /// The countdown caption shows for this long before they close.
    static let countdown: TimeInterval = 30
    static let settingsURL = URL(string: UIApplication.openSettingsURLString)!

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Reduce { state, action in
            switch action {
            case .appDelegate(.didFinishLaunching):
                // Start-up work (notification permission, background tasks) will hang off here.
                return .none

            case let .scenePhaseChanged(phase):
                state.scenePhase = phase
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
                if !state.path.isEmpty, let last = state.lastGrownupTouch {
                    let idle = now.timeIntervalSince(last)
                    if idle >= Self.idleLimit {
                        relock(&state)
                    } else if idle >= Self.idleLimit - Self.countdown {
                        state.relockCaption = "Locks in 0:\(String(format: "%02d", Int(Self.idleLimit - idle)))"
                    } else {
                        state.relockCaption = nil
                    }
                }
                return .send(.home(.tick(now)))

            case .home(.clockHoldCompleted):
                state.lock = .scanning
                return authenticate()

            case .parentAuthResponse(.success):
                state.lock = nil
                state.lastGrownupTouch = date.now
                state.path.append(.hub(GrownupHubFeature.State()))
                return .none

            case .parentAuthResponse(.notRecognised):
                state.lock = .notRecognised
                return .none

            case .parentAuthResponse(.cancelled):
                state.lock = nil
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
                    state.lock = nil
                    return .run { [openURL] _ in await openURL(Self.settingsURL) }
                default:
                    return .none
                }

            case .lockCancelTapped:
                state.lock = nil
                return .none

            case .grownupTouched:
                state.lastGrownupTouch = date.now
                state.relockCaption = nil
                return .none

            case .path(.element(id: _, action: .hub(.backTapped))):
                state.path.removeAll()
                state.lastGrownupTouch = nil
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

            case let .path(.element(id: id, action: .editor(.delegate(.finished)))):
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
            await send(.parentAuthResponse(parentAuth.authenticate("Open grown-up screens")))
        }
    }

    /// Back to the home screen; the next grown-up screen needs Face ID again. Unsaved forms are dropped.
    private func relock(_ state: inout State) {
        state.path.removeAll()
        state.lastGrownupTouch = nil
        state.relockCaption = nil
        state.lock = nil
    }
}

extension AppFeature.Path.State: Equatable {}
