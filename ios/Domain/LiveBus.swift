import Foundation

/// The bus type LTA reports for an arrival; it picks the bus picture.
public enum BusType: String, Codable, Hashable, Sendable {
    case double, single, bendy
}

/// One live arrival at our stop: the service number, minutes from now and the bus type.
public struct BusArrival: Hashable, Codable, Sendable {
    public var service: String
    public var minutes: Int
    public var type: BusType

    public init(service: String, minutes: Int, type: BusType) {
        self.service = service
        self.minutes = minutes
        self.type = type
    }
}

/// A kid's bus route (C2 "Our buses", plan A only): the stop, the bus numbers the kid takes and the
/// minutes that matter. Stop codes and bus numbers stay on the iPad (spec privacy rule).
public struct BusPlan: Hashable, Codable, Sendable {
    public static let defaultWalk = 10
    public static let defaultRide = 10
    public static let defaultLateGrace = 15

    public var kid: Kid.ID
    /// The event this route is for (spec "Events: one shape": a route per event); School by default.
    public var event: EventRef
    public var stop: String
    public var services: [String]
    public var walk: Int
    public var ride: Int
    public var lateGrace: Int

    public init(kid: Kid.ID, event: EventRef = .school, stop: String, services: [String],
                walk: Int = BusPlan.defaultWalk, ride: Int = BusPlan.defaultRide,
                lateGrace: Int = BusPlan.defaultLateGrace) {
        self.kid = kid
        self.event = event
        self.stop = stop
        self.services = services
        self.walk = walk
        self.ride = ride
        self.lateGrace = lateGrace
    }
}

extension BusPlan {
    /// Plans stored before routes were per event are the kid's School route, as they were.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kid: try values.decode(Kid.ID.self, forKey: .kid),
                  event: try values.decodeIfPresent(EventRef.self, forKey: .event) ?? .school,
                  stop: try values.decode(String.self, forKey: .stop),
                  services: try values.decode([String].self, forKey: .services),
                  walk: try values.decode(Int.self, forKey: .walk), ride: try values.decode(Int.self, forKey: .ride),
                  lateGrace: try values.decode(Int.self, forKey: .lateGrace))
    }

    /// The plan with the kid's school late grace, which wins over the plan's own (spec "Latest lives
    /// on the school record"); the plan's value stays for a kid with no school times.
    public func graced(by kid: Kid?) -> BusPlan {
        var plan = self
        if let grace = kid?.school?.lateGrace { plan.lateGrace = grace }
        return plan
    }
}

extension Array where Element == BusPlan {
    /// The kid's route for an event (School when not given).
    public func route(kid: Kid.ID, event: EventRef = .school) -> BusPlan? {
        first { $0.kid == kid && $0.event == event }
    }
}

/// The medal a kid gets for sliding to go, from the time only (spec "Medal from the time only").
public enum MorningMedal: String, Codable, Hashable, Sendable {
    case gold, silver, bronze, none
}

/// Spec "A2 live look": what the live morning shows for one bus outing at one minute.
public struct LiveMorning: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case onTime, leaveNow, askGrownup }

    /// The next two arrivals of the kid's buses at our stop, soonest first.
    public let shown: [BusArrival]
    /// The first arrival the kid can still walk to (minutes ≥ walk).
    public let chosen: BusArrival?
    /// An earlier arrival that cannot be caught, drawn faded with "too soon".
    public let tooSoon: BusArrival?
    /// Minutes until the kid should leave home for the chosen bus.
    public let leaveIn: Int?
    public let status: Status?

    /// - Parameters: `arrivals` all live arrivals at the stop; `minute` now (minutes after
    ///   midnight); `start` the outing's start (arrive-by).
    public init(arrivals: [BusArrival], plan: BusPlan, minute: Int, start: Int) {
        let mine = arrivals.filter { plan.services.contains($0.service) }.sorted { $0.minutes < $1.minutes }
        shown = Array(mine.prefix(2))
        let chosen = mine.first { $0.minutes >= plan.walk }
        self.chosen = chosen
        tooSoon = shown.first { $0.minutes < plan.walk }
        guard let chosen else {
            leaveIn = nil
            status = .askGrownup
            return
        }
        let leaveIn = chosen.minutes - plan.walk
        self.leaveIn = leaveIn
        let arrival = minute + chosen.minutes + plan.ride
        if arrival > start + plan.lateGrace {
            status = .askGrownup
        } else if leaveIn <= 0 {
            status = .leaveNow
        } else if arrival <= start {
            status = .onTime
        } else {
            status = nil
        }
    }

    /// L1 and L2 (spec): the leave times of the last bus that still gets the kid there by the start
    /// (L1) and by the start + late grace (L2), from the arrivals at the moment of the slide.
    public static func leaveTargets(arrivals: [BusArrival], plan: BusPlan, minute: Int,
                                    start: Int) -> (ideal: Int, latest: Int)? {
        let mine = arrivals.filter { plan.services.contains($0.service) }
        func lastLeave(by deadline: Int) -> Int? {
            mine.filter { minute + $0.minutes + plan.ride <= deadline }
                .map { minute + $0.minutes - plan.walk }
                .max()
        }
        guard let latest = lastLeave(by: start + plan.lateGrace) else { return nil }
        return (lastLeave(by: start) ?? latest, latest)
    }

    /// The timetable fallback: L1 = start − leave before, L2 = L1 + late grace.
    public static func timetableTargets(start: Int, leaveBefore: Int,
                                        lateGrace: Int = BusPlan.defaultLateGrace) -> (ideal: Int, latest: Int) {
        let ideal = start - leaveBefore
        return (ideal, ideal + lateGrace)
    }

    /// Gold at or before L1 − 5, silver at or before L1, bronze at or before L2, else none.
    public static func medal(readyAt: Int, ideal: Int, latest: Int) -> MorningMedal {
        if readyAt <= ideal - 5 { return .gold }
        if readyAt <= ideal { return .silver }
        if readyAt <= latest { return .bronze }
        return .none
    }
}
