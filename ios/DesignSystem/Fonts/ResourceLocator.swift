import Foundation

/// Finds this module's resource bundles: inside the app, or inside an unhosted test bundle
/// (where `Bundle.main` is the test runner, not us).
enum ResourceLocator {
    static func bundle(named name: String) -> Bundle? {
        [Bundle(for: BundleToken.self), Bundle.main].lazy  // outside-ok: resource lookup
            .compactMap { $0.url(forResource: name, withExtension: "bundle") }
            .compactMap(Bundle.init(url:))
            .first
    }

    private final class BundleToken {}
}
