import ComposableArchitecture
import DesignSystem
import UIKit

/// Owns the root store and turns UIKit lifecycle callbacks into `AppFeature` actions.
/// The app target subclasses this and overrides `bootstrap` to inject live dependencies;
/// nothing else belongs in the app target.
@MainActor
open class AppDelegateBase: NSObject, UIApplicationDelegate {
    public private(set) lazy var store: StoreOf<AppFeature> = Store(initialState: AppFeature.State()) {
        AppFeature()
    } withDependencies: { [unowned self] dependencies in
        self.bootstrap(&dependencies)
    }

    override public init() {
        super.init()
    }

    /// Override to replace interface dependencies with their live implementations.
    open func bootstrap(_ dependencies: inout DependencyValues) {}

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FontRegistrar.registerAll()
        store.send(.appDelegate(.didFinishLaunching))
        return true
    }
}
