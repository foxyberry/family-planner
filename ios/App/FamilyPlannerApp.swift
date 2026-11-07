// The app target stays thin: entry point + live dependency injection only.
// Screens, state and lifecycle handling live in AppCore.
import AppCore
import ComposableArchitecture
import ParentAuthClient
import ParentAuthClientLive
import SwiftUI

final class AppDelegate: AppDelegateBase {
    override func bootstrap(_ dependencies: inout DependencyValues) {
        dependencies.parentAuth = .live
    }
}

@main
struct FamilyPlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        AppScene(store: appDelegate.store)
    }
}
