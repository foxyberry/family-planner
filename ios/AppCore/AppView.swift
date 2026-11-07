import ComposableArchitecture
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 32) {
                Text(store.now?.formatted(date: .omitted, time: .standard) ?? "--:--:--")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Button("Parent") { store.send(.parentButtonTapped) }
                    .buttonStyle(.bordered)
            }
            .task { await store.send(.task).finish() }
        } destination: { store in
            switch store.case {
            case let .parentHome(store):
                ParentHomeView(store: store)
            }
        }
    }
}
