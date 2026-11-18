import Foundation

/// Looks user-facing copy up in the String Catalog (`Localizable.xcstrings`, table "Localizable").
/// Keys are semantic, lower-case and dotted: `lock.enter`, `editor.confirm.leave.title`.
/// A key missing from the catalog shows as the key itself, so it stands out on screen;
/// `scripts/check-strings.sh` blocks such a key before it is pushed.
///
/// Views hold no values (user, 2026-11-18): screens get their copy from State, and State gets this
/// value from the injected `\.localizer` dependency (module `Localization`), so a test or a new
/// language can swap it. Views never call `tr` (`scripts/check-view-values.sh`).
public struct Localizer: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        /// The catalog's copy in one language ("en").
        case catalog(language: String)
        /// The key itself, then its arguments: "kid.left|3|Kid A". Tests that check which copy a
        /// state picks, without depending on its English wording.
        case keys
    }

    public let source: Source

    public init(_ source: Source) {
        self.source = source
    }

    /// The catalog in the language the app's bundle picked.
    public static let app = Localizer(.catalog(language: Catalog.preferredLanguage))
    /// The catalog in English (tests, which assert English copy).
    public static let english = Localizer(.catalog(language: "en"))
    /// Keys instead of copy (see `Source.keys`).
    public static let keys = Localizer(.keys)

    public func tr(_ key: StaticString, _ args: CVarArg...) -> String {
        tr("\(key)", arguments: args)
    }

    func tr(_ key: String, arguments args: [CVarArg]) -> String {
        switch source {
        case .keys:
            return ([key] + args.map { "\($0)" }).joined(separator: "|")
        case let .catalog(language):
            guard let bundle = Catalog.bundle(for: language) else { return key }
            let format = bundle.localizedString(forKey: key, value: nil, table: "Localizable") // copy-ok: table name
            guard !args.isEmpty else { return format }
            // Numbers are written in the language the copy came from, never the device's locale.
            return String(format: format, locale: Locale(identifier: language), arguments: args)
        }
    }
}

/// Today's static lookup, in the app's language. Being replaced by `Localizer` read from State
/// (views first; Domain formatters and State files follow).
public enum L10n {
    public static func tr(_ key: StaticString, _ args: CVarArg...) -> String {
        Localizer.app.tr("\(key)", arguments: args)
    }
}

/// Strings.bundle and its language folders.
enum Catalog {
    static let bundle = ResourceLocator.bundle(named: "Strings") // copy-ok: bundle name

    static let preferredLanguage = bundle?.preferredLocalizations.first ?? "en"

    /// The language's folder inside Strings.bundle; the bundle itself when it has none.
    static func bundle(for language: String) -> Bundle? {
        guard let bundle else { return nil }
        guard let path = bundle.path(forResource: language, ofType: "lproj") else { return bundle }
        return Bundle(path: path) ?? bundle
    }
}

/// Finds Strings.bundle: inside the app, or inside an unhosted test bundle
/// (where `Bundle.main` is the test runner, not us).
enum ResourceLocator {
    static func bundle(named name: String) -> Bundle? {
        [Bundle(for: BundleToken.self), .main].lazy
            .compactMap { $0.url(forResource: name, withExtension: "bundle") }
            .compactMap(Bundle.init(url:))
            .first
    }

    private final class BundleToken {}
}
