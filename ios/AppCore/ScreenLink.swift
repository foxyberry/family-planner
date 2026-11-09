import Foundation

/// Screen deep links (`familyplanner://missions`): open a screen straight away, for a link from
/// outside and for checking a screen on the iPad (`make device OPEN=missions`).
public enum ScreenLink: Equatable, Sendable {
    /// The kid clock.
    case home
    /// A2 · Morning.
    case missions
    /// A grown-up board (`familyplanner://c2`), debug builds only: it opens after the usual
    /// unlock (Face ID, or "Enter" without it), so a link never skips the lock.
    case grownup(GrownupBoard)
    /// First-run setup at step 1–4 (`familyplanner://s2`), debug builds only: S2–S4 come filled
    /// with the sample family. No unlock (setup has none); nothing is saved until Start.
    case setup(Int)

    public static let scheme = "familyplanner" // copy-ok: URL scheme

    /// The link a URL names, or nil for another scheme or an unknown screen.
    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        switch host {
        case "home": self = .home // copy-ok: link name
        case "missions": self = .missions // copy-ok: link name
        default:
            #if DEBUG
            if let step = ["s1", "s2", "s3", "s4"].firstIndex(of: host) { // copy-ok: link names
                self = .setup(step + 1)
                return
            }
            guard let board = GrownupBoard(rawValue: host) else { return nil }
            self = .grownup(board)
            #else
            // A release build has no grown-up links: without Face ID the 2-second hold is the gate.
            return nil
            #endif
        }
    }
}

/// The grown-up boards a debug link can open, by their board id (spec "C1 · Our kids", …).
public enum GrownupBoard: String, CaseIterable, Equatable, Sendable {
    /// C1 · Our kids, the first kid.
    case c1
    /// E6 · Our kids, the second kid.
    case e6
    /// C2 · Our buses.
    case c2
    /// C3 · Add to the day, every week.
    case c3
    /// C4 · Add to the day, just once.
    case c4
    /// C5 · Morning missions.
    case c5
    /// C6 · Our day.
    case c6
}
