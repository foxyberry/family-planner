import ComposableArchitecture
#if DEBUG
import DebugTools
#endif
import DesignSystem
import Grownup
import Home
import Missions
import KitArt
import Setup
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            if let setup = store.scope(state: \.setup, action: \.setup) {
                // First run (S1–S4): no home and no grown-up lock until the family is saved.
                SetupView(store: setup)
            } else if store.hasFamily == nil {
                // The store is read once at launch; plain paper until then, never an empty home.
                CrayonColor.paper.ignoresSafeArea()
            } else {
                navigation
            }
            // Also read the scene phase here, so the cover is drawn before the system takes its snapshot
            // even if the reducer has not seen the change yet.
            if store.coversGrownupScreens || (scenePhase != .active && store.hasGrownupScreens) {
                CrayonColor.paper.ignoresSafeArea()
            }
            if let lock = store.lock {
                LockOverlay(state: lock, onPrimary: { store.send(.lockPrimaryTapped) },
                            onCancel: { store.send(.lockCancelTapped) })
            }
            #if DEBUG
            if let debugTools = DebugModel.installed {
                DebugOverlay(model: debugTools,
                             lines: store.setup != nil ? .grownup
                                 : store.isShowingMissions ? .morning : store.path.isEmpty ? .home : .grownup)
            }
            #endif
        }
        #if DEBUG
        // "Load sample family" in the debug menu replaced the stored family.
        .onChange(of: DebugModel.installed?.familyGeneration) { store.send(.familyReplaced) }
        #endif
        // One colour scheme for the window, set here because a pushed screen cannot override the home
        // underneath: grown-up screens follow the iPad's dark mode through the colour tokens.
        .preferredColorScheme(colorScheme)
        .environment(\.crayonOutline, CrayonColor.outline)
        .environment(\.rigScale, Self.rigScale)
        // Spec "Sizing formulas": one Sizing for the window, read once here.
        .readsSizing()
        // The 1-second tick lives on the root, not on the home screen: a pushed grown-up screen makes
        // the home disappear, which would cancel its task and stop the idle relock.
        .task { store.send(.checkFamily) }
        .task { await store.send(.task).finish() }
    }

    private var colorScheme: ColorScheme? {
        #if DEBUG
        if let dark = DebugModel.installed?.forcedDark, store.colorScheme == nil { return dark ? .dark : .light }
        #endif
        return store.colorScheme
    }

    /// The debug menu's "Rig scale" in debug builds; the kit data's scale otherwise.
    private static var rigScale: Double {
        #if DEBUG
        DebugModel.installed?.rigScale ?? KitRigs.shared.scale
        #else
        KitRigs.shared.scale
        #endif
    }

    private var navigation: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
        } destination: { store in
            switch store.case {
            case let .missions(store):
                // Pushed over home; its own ← goes back (no system bar or edge swipe).
                MissionsView(store: store)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden()
            case let .settings(store):
                SettingsView(store: store)
            case let .editor(store):
                ItemEditorView(store: store)
            case let .ourDay(store):
                OurDayView(store: store)
            case let .missionEditor(store):
                MissionEditorView(store: store)
            case let .busSettings(store):
                BusSettingsView(store: store)
            case let .dataSources(store):
                DataSourcesView(store: store)
            case let .gallery(store):
                ComponentGallery(onBack: { store.send(.backTapped) })
            }
        }
        // Any touch on a grown-up screen keeps it open for another 2 minutes.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
            if store.hasGrownupScreens { store.send(.grownupTouched) }
        })
        .environment(\.relockCaption, store.relockCaption)
    }
}
