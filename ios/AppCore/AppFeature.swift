import ComposableArchitecture
import Foundation
import Home
import ParentAuthClient
import SwiftUI

/// Root of the app. Lifecycle events arrive here as actions so they can be tested
/// like any other feature; the app target only forwards them.
@Reducer
public struct AppFeature {
    @Reducer
    public enum Path {
        case parentHome(ParentHomeFeature)
        case gallery(GalleryFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var now: Date?
        public var scenePhase: ScenePhase = .inactive
        public var path = StackState<Path.State>()
        public var home = HomeFeature.State()

        public init() {}
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
        case path(StackActionOf<Path>)
        case home(HomeFeature.Action)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date
    @Dependency(\.parentAuth) var parentAuth

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
                return .none

            case .task:
                return .run { [clock, date] send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.tick(date.now))
                    }
                }

            case let .tick(now):
                state.now = now
                return .send(.home(.tick(now)))

            case .home(.clockHoldCompleted):
                return .run { [parentAuth] send in
                    await send(.parentAuthResponse(parentAuth.authenticate("Open parent mode")))
                }

            case .parentAuthResponse(.success):
                state.path.append(.parentHome(ParentHomeFeature.State()))
                return .none

            case .parentAuthResponse:
                return .none

            case .path(.element(id: _, action: .parentHome(.galleryButtonTapped))):
                state.path.append(.gallery(GalleryFeature.State()))
                return .none

            case .path, .home:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension AppFeature.Path.State: Equatable {}
