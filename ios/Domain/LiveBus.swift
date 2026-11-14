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
    /// The kid's buses in order (spec "1st and 2nd choice"): the 1st is "my bus", an optional 2nd is
    /// shown faded and never switched to. "Leave in", the status and the medal use the 1st only.
    public var services: [String]
    public var walk: Int
    public var ride: Int
    public var lateGrace: Int
    /// "Ride 2nd": the 2nd bus's own ride time (often the long way); the 1st's ride when not set.
    public var secondRide: Int?
    /// A 2nd choice that changes buses (board C2c). One 2nd choice per kid: with a change the
    /// services hold the 1st only.
    public var change: BusChange?

    public init(kid: Kid.ID, event: EventRef = .school, stop: String, services: [String],
                walk: Int = BusPlan.defaultWalk, ride: Int = BusPlan.defaultRide,
                lateGrace: Int = BusPlan.defaultLateGrace, secondRide: Int? = nil, change: BusChange? = nil) {
        self.secondRide = secondRide
        self.change = change
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
                  lateGrace: try values.decode(Int.self, forKey: .lateGrace),
                  secondRide: try values.decodeIfPresent(Int.self, forKey: .secondRide),
                  change: try values.decodeIfPresent(BusChange.self, forKey: .change))
    }

    /// The 1st-choice bus ("my bus").
    public var first: String? { services.first }
    /// The 2nd choice, if any: a direct bus from our stop.
    public var second: String? { services.count > 1 ? services[1] : nil }
    /// The bus the 2nd choice starts on at our stop: the direct 2nd, or a changing route's first bus.
    public var secondStart: String? { change?.firstBus ?? second }

    /// The plan with a changing 2nd choice (C2c Save): it replaces a direct 2nd; nil removes it.
    public func changing(_ change: BusChange?) -> BusPlan {
        var plan = self
        plan.change = change
        if change != nil {
            plan.services = Array(services.prefix(1))
            plan.secondRide = nil
        }
        return plan
    }

    /// C2's Buses pills (spec "C2 rows"): the first tap makes a bus the 1st, the next the 2nd (a
    /// third replaces the 2nd); a tap on a picked bus clears it, and a cleared 1st hands over to the 2nd.
    public static func toggling(_ service: String, in services: [String]) -> [String] {
        var list = Array(services.prefix(2))
        if let index = list.firstIndex(of: service) {
            list.remove(at: index)
        } else if list.count < 2 {
            list.append(service)
        } else {
            list[1] = service
        }
        return list
    }

    /// The plan with the kid's school late grace, which wins over the plan's own (spec "Latest lives
    /// on the school record"); the plan's value stays for a kid with no school times.
    public func graced(by kid: Kid?) -> BusPlan {
        var plan = self
        if let grace = kid?.school?.lateGrace { plan.lateGrace = grace }
        return plan
    }
}

/// A 2nd choice that changes buses (spec "C2c"): a first bus from our stop to a change stop, a walk
/// between, then a second bus to school.
public struct BusChange: Hashable, Codable, Sendable {
    public var firstBus: String
    /// The change stop's 5-digit code.
    public var stop: String
    public var thenBus: String
    public var ride1: Int
    public var walk: Int
    public var ride2: Int

    public init(firstBus: String, stop: String, thenBus: String, ride1: Int = BusPlan.defaultRide, walk: Int = 2,
                ride2: Int = BusPlan.defaultRide) {
        self.firstBus = firstBus
        self.stop = stop
        self.thenBus = thenBus
        self.ride1 = ride1
        self.walk = walk
        self.ride2 = ride2
    }

    /// How a changing 2nd choice's change goes (spec "A2 strip"): "wait {n} min", "tight", "will miss".
    public enum Fit: Equatable, Sendable {
        case wait(Int)
        case tight
        case willMiss
    }

    /// Spec "A2 strip": the kid boards `firstBus` in `boardsIn` minutes, rides, walks, and catches the
    /// next `thenBus` arriving at the change stop (live `arrivals` there). Under 2 minutes is tight.
    public func fit(boardsIn: Int, arrivals: [BusArrival]) -> Fit {
        let atStop = boardsIn + ride1 + walk
        guard let next = arrivals.filter({ $0.service == thenBus && $0.minutes >= atStop }).map(\.minutes).min() else {
            return .willMiss
        }
        let wait = next - atStop
        return wait < 2 ? .tight : .wait(wait)
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
    /// The 2nd choice's next bus the kid can still walk to, drawn faded with "or · 2nd" (or the
    /// changing route's first bus).
    public let second: BusArrival?
    /// A changing 2nd choice: how its change goes for that bus; nil without live times at the change stop.
    public let secondFit: BusChange.Fit?
    /// Minutes until the kid should leave home for the chosen bus.
    public let leaveIn: Int?
    public let status: Status?

    /// - Parameters: `arrivals` all live arrivals at the stop; `minute` now (minutes after
    ///   midnight); `start` the outing's start (arrive-by).
    ///   `changeArrivals` the live arrivals at a changing 2nd choice's change stop.
    public init(arrivals: [BusArrival], plan: BusPlan, minute: Int, start: Int, changeArrivals: [BusArrival]? = nil) {
        let mine = arrivals.filter { $0.service == plan.first }.sorted { $0.minutes < $1.minutes }
        let second = arrivals.filter { $0.service == plan.secondStart && $0.minutes >= plan.walk }.min { $0.minutes < $1.minutes }
        self.second = second
        if let change = plan.change, let second, let changeArrivals {
            secondFit = change.fit(boardsIn: second.minutes, arrivals: changeArrivals)
        } else {
            secondFit = nil
        }
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
        let mine = arrivals.filter { $0.service == plan.first }
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
