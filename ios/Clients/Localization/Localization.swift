import ComposableArchitecture
import Strings

/// Views hold no values (user, 2026-11-18): copy reaches State through this dependency, so a test
/// or another language can swap it. The live value is a lookup in our own Strings.bundle (no
/// system framework), so it lives here and needs no `*Live` module or bootstrap line.
private enum LocalizerKey: DependencyKey {
    static let liveValue = Localizer.app
    /// Tests assert English copy; a test that checks keys sets `.keys`.
    static let testValue = Localizer.english
    static let previewValue = Localizer.app
}

extension DependencyValues {
    public var localizer: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}

extension Localizer {
    /// The injected localizer, for a State's stored `strings` (`public var strings = Localizer.injected`).
    /// TCA builds initial and child State inside the store's dependencies, so this is the store's value.
    /// Never read it in a computed property: a view evaluating that would get the default instead.
    public static var injected: Localizer {
        @Dependency(\.localizer) var localizer
        return localizer
    }
}
