import Foundation

/// The app's own values that must not be in the public repo, built in from the git-ignored
/// `Private/LocalConfig.json` (copy `DeviceConfig.example.json` and fill it in). Only the LTA
/// DataMall key lives here: it is the app's, the same for every family. A family's stop, buses and
/// minutes are their data and are entered in the app (C2, later first-run setup S3).
public struct DeviceConfig: Decodable, Equatable, Sendable {
    /// The LTA DataMall AccountKey for live bus times.
    public var busKey: String?

    public init(busKey: String? = nil) {
        self.busKey = busKey
    }

    /// The built-in config, or nil when the app was built without one (CI, clones).
    public static let bundled: DeviceConfig? = {
        guard let url = resourceBundle?.url(forResource: "LocalConfig", withExtension: "json"), // copy-ok: file name
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DeviceConfig.self, from: data)
    }()

    /// A key that is filled in (the example's placeholder is not a key).
    public var usableBusKey: String? {
        guard let busKey, !busKey.isEmpty, !busKey.hasPrefix("your-") else { return nil } // copy-ok: placeholder prefix
        return busKey
    }

    private static var resourceBundle: Bundle? {
        let home = Bundle(for: BundleToken.self)
        return [home, .main].lazy
            .compactMap { $0.url(forResource: "DeviceConfigResources", withExtension: "bundle") } // copy-ok: bundle name
            .compactMap(Bundle.init(url:))
            .first
    }
}

private final class BundleToken {}
