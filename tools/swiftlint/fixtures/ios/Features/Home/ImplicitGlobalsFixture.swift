// Fixture for outside_data (not compiled): the global member names never go without their type
// (user, 2026-11-22). Every line marked `bad` must be reported, and no other line.
import SwiftUI

struct ImplicitGlobalsFixture {
    let zone: TimeZone = .current  // bad
    let maybe: Calendar? = .autoupdatingCurrent  // bad
    let start: Date = .now  // bad
    let arguments: ProcessInfo = .processInfo  // bad
    let bundle: Bundle = .main  // bad
    let defaults: UserDefaults = .standard  // bad
    let marker: MarkerStyle = .standard  // bad
    let style: TextStyle = .current  // bad
    let bundles = [Bundle(for: Token.self), .main]  // bad

    func days(calendar: Calendar = .current) {}  // bad

    func calls(formatter: DateFormatter, calendar: Calendar) {
        plan(.current)  // bad
        plan(calendar: .current)  // bad
        formatter.locale = .current  // bad
        draw(marker: .standard.with(width: 2))  // bad
        plan(calendar: calendar)
        formatter.dateStyle = .medium
        draw(marker: MarkerStyle.standard.with(width: 2))
        draw(marker: .thin)
    }

    // Written with their type: our own types pass; a global read needs its reason on the line.
    let explicitMarker = MarkerStyle.standard
    let explicitStyle = TextStyle.current
    let resources = [Bundle(for: Token.self), Bundle.main]  // outside-ok: resource lookup
    let unexplained = [Bundle(for: Token.self), Bundle.main]  // bad
    let noReason = Bundle.main  // outside-ok: // bad (a note with no reason)
    let queue = DispatchQueue.main
}
