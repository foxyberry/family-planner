import ComposableArchitecture
#if DEBUG
import DebugTools
#endif
import DesignSystem
import Grownup
import Home
import Missions
import KitArt
import SchoolYear
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
            if let card = store.lockCard {
                LockOverlay(title: card.title, message: card.message, primary: card.primary, cancel: card.cancel,
                            onPrimary: { store.send(.lockPrimaryTapped) }, onCancel: { store.send(.lockCancelTapped) })
            }
            #if DEBUG
            if let debugTools = DebugModel.installed {
                DebugOverlay(model: debugTools, lines: Self.gridLines(store.screenFamily))
            }
            #endif
        }
        #if DEBUG
        // "Load sample family" in the debug menu replaced the stored family.
        .onChange(of: DebugModel.installed?.familyGeneration) { store.send(.familyReplaced) }
        // `-fpDriver`: the agent driver answers `ls` and `do` on 127.0.0.1 (Journeys/Tests/Driver).
        .task { await serveDriver() }
        #endif
        // One colour scheme for the window, set here because a pushed screen cannot override the home
        // underneath: grown-up screens follow the iPad's dark mode through the colour tokens.
        .preferredColorScheme(store.colorScheme)
        .environment(\.crayonOutline, CrayonColor.outline)
        .environment(\.rigScale, Self.rigScale)
        // Spec "Keyboard": the keyboard client's one decision reaches every screen.
        .environment(\.keyboardTop, store.keyboardTop)
        .animation(.easeOut(duration: store.keyboardDuration), value: store.keyboardTop)
        // Spec "Sizing: one scale, no floors": one Sizing from the app window, again on every resize.
        .readsSizing()
        // The page around the board frame for screens outside the navigation stack (setup, the
        // first paper): the top screen's page (paper, or the night sky).
        .background { store.pageLook.page.ignoresSafeArea() }
        // The 1-second tick lives on the root, not on the home screen: a pushed grown-up screen makes
        // the home disappear, which would cancel its task and stop the clock.
        .task { store.send(.checkFamily) }
        .task { await store.send(.task).finish() }
    }

    #if DEBUG
    /// The agent driver while `-fpDriver` asked for it: each request reads or acts on this store
    /// through the contract's names only (`AgentContract`). Nothing listens otherwise.
    private func serveDriver() async {
        guard let port = DebugModel.installed?.driverPort else { return }
        let store = store
        await AgentServer.serve(port: port) { request in
            await MainActor.run {
                switch AgentContract.reply(method: request.method, path: request.path, body: request.body,
                                           state: store.state) {
                case let .answer(status, json):
                    return AgentServer.Response(status: status, body: json)
                case let .send(action):
                    store.send(action)
                    return AgentServer.Response(status: 200, body: AgentContract.lsJSON(store.state))
                }
            }
        }
    }
    #endif

    /// The debug menu's "Rig scale" in debug builds; the kit data's scale otherwise.
    private static var rigScale: Double {
        #if DEBUG
        DebugModel.rigScale
        #else
        KitRigs.shared.scale
        #endif
    }

    #if DEBUG
    /// The layout grid for the board family on top.
    private static func gridLines(_ family: AppFeature.State.ScreenFamily) -> GridLines {
        switch family {
        case .home: .home
        case .morning: .morning
        case .grownup: .grownup
        }
    }
    #endif

    private var navigation: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
                .boardFrame()
        } destination: { store in
            Group {
                switch store.case {
                case let .missions(store):
                    // Pushed over home; its own ← goes back (no system bar or edge swipe).
                    MissionsView(store: store)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden()
                case let .schoolYear(store):
                    // K1, pushed over home; its own "‹" goes back.
                    SchoolYearView(store: store)
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
                case let .changeBuses(store):
                    ChangeBusesView(store: store)
                case let .schoolEditor(store):
                    SchoolEditorView(store: store)
                case let .addChild(store):
                    AddChildView(store: store)
                case let .changeSchool(store):
                    ChangeSchoolView(store: store)
                case let .dataSources(store):
                    DataSourcesView(store: store)
                }
            }
            .boardFrame()
        }
        // A NavigationStack hosts each screen in its own UIKit view and clips it to the stack's width.
        // The stack spans the window and frames its screens back to the board, so a pushed screen's
        // dim layer or veil (`fullBleed()`) reaches the window's sides and takes their taps.
        .spansWindow()
    }
}
