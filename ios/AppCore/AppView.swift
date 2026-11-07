import ComposableArchitecture
import DesignSystem
import Grownup
import Home
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            navigation
            if store.coversGrownupScreens {
                CrayonColor.paper.ignoresSafeArea()
            }
            if let lock = store.lock {
                LockOverlay(state: lock, onPrimary: { store.send(.lockPrimaryTapped) },
                            onCancel: { store.send(.lockCancelTapped) })
            }
        }
    }

    private var navigation: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
                .task { await store.send(.task).finish() }
        } destination: { store in
            switch store.case {
            case let .hub(store):
                GrownupHubView(store: store)
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
