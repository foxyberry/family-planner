import Foundation

public extension DayPlanner {
    /// The days off for an item's audience: the kid's own, or for both kids the days off for both.
    static func daysOff(for audience: Audience, in daysOff: [Kid.ID: Set<Day>]) -> Set<Day> {
        switch audience {
        case let .kid(id): daysOff[id] ?? []
        case .both: daysOff.values.dropFirst().reduce(daysOff.values.first ?? []) { $0.intersection($1) }
        }
    }
}
