import Foundation

/// User-facing copy from the String Catalog (`Localizable.xcstrings`, table "Localizable").
/// Keys are semantic, lower-case and dotted: `lock.enter`, `editor.confirm.leave.title`.
/// A key missing from the catalog shows as the key itself, so it stands out on screen;
/// `scripts/check-strings.sh` blocks such a key before it is pushed.
public enum L10n {
    public static func tr(_ key: StaticString, _ args: CVarArg...) -> String {
        let key = "\(key)"
        guard let bundle else { return key }
        let format = bundle.localizedString(forKey: key, value: nil, table: "Localizable") // copy-ok: table name
        guard !args.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: args)
    }

    private static let bundle = ResourceLocator.bundle(named: "Strings") // copy-ok: bundle name

    /// Numbers are written in the language the copy came from, never the device's locale.
    private static let locale = Locale(identifier: bundle?.preferredLocalizations.first ?? "en")
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
