import ComposableArchitecture
import DesignSystem
import Home
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
                .task { await store.send(.task).finish() }
        } destination: { store in
            switch store.case {
            case let .parentHome(store):
                ParentHomeView(store: store)
            case .gallery:
                ComponentGallery()
            }
        }
    }
}
