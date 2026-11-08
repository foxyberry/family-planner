import Foundation

/// Screen deep links (`familyplanner://missions`): open a kid screen straight away, for a link
/// from outside and for checking a screen on the iPad (`make device OPEN=missions`). Grown-up
/// screens stay behind the hold and Face ID, so they have no link.
public enum ScreenLink: Equatable, Sendable {
    /// The kid clock.
    case home
    /// A2 · Morning.
    case missions

    public static let scheme = "familyplanner" // copy-ok: URL scheme

    /// The link a URL names, or nil for another scheme or an unknown screen.
    public init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "home": self = .home // copy-ok: link name
        case "missions": self = .missions // copy-ok: link name
        default: return nil
        }
    }
}
