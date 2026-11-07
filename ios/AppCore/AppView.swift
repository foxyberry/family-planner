import ComposableArchitecture
import DesignSystem
import Grownup
import Home
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            navigation
            // Also read the scene phase here, so the cover is drawn before the system takes its snapshot
            // even if the reducer has not seen the change yet.
            if store.coversGrownupScreens || (scenePhase != .active && !store.path.isEmpty) {
                CrayonColor.paper.ignoresSafeArea()
            }
            if let lock = store.lock {
                LockOverlay(state: lock, onPrimary: { store.send(.lockPrimaryTapped) },
                            onCancel: { store.send(.lockCancelTapped) })
            }
        }
        // The 1-second tick lives on the root, not on the home screen: a pushed grown-up screen makes
        // the home disappear, which would cancel its task and stop the idle relock.
        .task { await store.send(.task).finish() }
    }

    private var navigation: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
        } destination: { store in
            switch store.case {
            case let .hub(store):
                GrownupHubView(store: store)
            case let .editor(store):
                ItemEditorView(store: store)
            case .gallery:
                ComponentGallery()
            }
        }
        // Any touch on a grown-up screen keeps it open for another 2 minutes.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
            if !store.path.isEmpty { store.send(.grownupTouched) }
        })
        .environment(\.relockCaption, store.relockCaption)
    }
}
