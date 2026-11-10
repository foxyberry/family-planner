// The app target stays thin: entry point + live dependency injection only.
// Screens, state and lifecycle handling live in AppCore.
import AppCore
import AppSettings
import AppSettingsLive
import BusClient
import BusClientLive
import ComposableArchitecture
import DeviceConfig
import DeviceLook
import DeviceLookLive
#if DEBUG
import DebugTools
#endif
import HolidayProvider
import HolidayProviderLive
import ParentAuthClient
import ParentAuthClientLive
import SchoolDirectory
import SchoolDirectoryLive
import ScheduleStore
import ScheduleStoreLive
import SwiftUI

final class AppDelegate: AppDelegateBase {
    override func bootstrap(_ dependencies: inout DependencyValues) {
        dependencies.parentAuth = .live
        dependencies.appSettings = .live()
        dependencies.deviceLook = .live
        dependencies.holidays = .live
        dependencies.scheduleStore = .live(directory: .applicationSupportDirectory)
        dependencies.schoolDirectory = .live
        dependencies.bus = .live(key: DeviceConfig.bundled?.usableBusKey)
        #if DEBUG
        DebugModel.install(into: &dependencies)
        #endif
    }
}

@main struct FamilyPlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        AppScene(store: appDelegate.store)
    }
}
