import AppSettings
import Foundation

extension AppSettingsClient {
    /// The switches as one JSON value in this iPad's user defaults. The family settings (live bus
    /// times, medals) move to the family store once families sync; until then this iPad holds all.
    public static func live(defaults: UserDefaults = .standard) -> AppSettingsClient {
        let key = "appSettings" // copy-ok: storage key
        // UserDefaults is thread-safe; the box only tells Swift 6 so.
        let store = UncheckedBox(defaults)
        return AppSettingsClient(
            load: {
                guard let data = store.value.data(forKey: key),
                      let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return .defaults }
                return settings
            },
            save: { settings in
                if let data = try? JSONEncoder().encode(settings) { store.value.set(data, forKey: key) }
            }
        )
    }
}

private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
