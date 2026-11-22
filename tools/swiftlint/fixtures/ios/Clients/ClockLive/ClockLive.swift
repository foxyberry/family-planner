// Fixture for outside_data (not compiled): a *Live client reads the outside world; that is its job.
import Foundation

enum ClockLive {
    static func now() -> Date { Date() }
    static let zone = TimeZone.current
}
