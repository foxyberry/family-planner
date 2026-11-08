import ComposableArchitecture
import SwiftUI

/// The app's only scene. Forwards scene-phase changes to the store.
public struct AppScene: Scene {
    let store: StoreOf<AppFeature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .onOpenURL { url in
                    if let link = ScreenLink(url: url) { store.send(.linkOpened(link)) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            store.send(.scenePhaseChanged(phase))
        }
    }
}
