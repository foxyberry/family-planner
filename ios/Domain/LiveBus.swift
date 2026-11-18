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

/// A kid's bus route (C2 "Our buses", plan A only): the stop, the kid's buses and the minutes that
/// matter. Stop codes and bus numbers stay on the iPad (spec privacy rule).
public struct BusPlan: Hashable, Sendable {
    public static let defaultWalk = 10
    public static let defaultRide = 10
    public static let defaultLateGrace = 15

    public var kid: Kid.ID
    /// The event this route is for (spec "Events: one shape": a route per event); School by default.
    public var event: EventRef
    public var stop: String
    /// Spec "Several buses": the kid's buses from our stop, all equal, in pill order. On the morning
    /// the one that gets the kid there first is "my bus".
    public var services: [String]
    public var walk: Int
    /// The ride for a bus with no ride of its own (a new pick starts with it).
    public var ride: Int
    public var lateGrace: Int
    /// Each bus's own ride ("Ride on 12"): buses can take different ways.
    public var rides: [String: Int]
    /// A bus that changes (board C2c), one more equal bus of the kid.
    public var change: BusChange?

    public init(kid: Kid.ID, event: EventRef = .school, stop: String, services: [String],
                walk: Int = BusPlan.defaultWalk, ride: Int = BusPlan.defaultRide,
                lateGrace: Int = BusPlan.defaultLateGrace, rides: [String: Int] = [:], change: BusChange? = nil) {
        self.kid = kid
        self.event = event
        self.stop = stop
        self.services = services
        self.walk = walk
        self.ride = ride
        self.lateGrace = lateGrace
        self.rides = rides
        self.change = change
    }
}

extension BusPlan: Codable {
    private enum CodingKeys: String, CodingKey {
        case kid, event, stop, services, walk, ride, lateGrace, rides, change
        /// Before "Several buses": the 2nd bus's own ride.
        case secondRide
    }

    /// Plans stored before routes were per event are the kid's School route. Plans stored before
    /// "Several buses" keep their buses: the 1st and 2nd become two equal buses, each with its own
    /// ride (the 2nd's "Ride 2nd"), and a changing 2nd becomes the bus that changes.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let services = try values.decode([String].self, forKey: .services)
        let ride = try values.decode(Int.self, forKey: .ride)
        var rides = try values.decodeIfPresent([String: Int].self, forKey: .rides) ?? [:]
        if let secondRide = try values.decodeIfPresent(Int.self, forKey: .secondRide), services.count > 1,
           rides.isEmpty {
            rides[services[1]] = secondRide
        }
        self.init(kid: try values.decode(Kid.ID.self, forKey: .kid),
                  event: try values.decodeIfPresent(EventRef.self, forKey: .event) ?? .school,
                  stop: try values.decode(String.self, forKey: .stop), services: services,
                  walk: try values.decode(Int.self, forKey: .walk), ride: ride,
                  lateGrace: try values.decode(Int.self, forKey: .lateGrace), rides: rides,
                  change: try values.decodeIfPresent(BusChange.self, forKey: .change))
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(kid, forKey: .kid)
        try values.encode(event, forKey: .event)
        try values.encode(stop, forKey: .stop)
        try values.encode(services, forKey: .services)
        try values.encode(walk, forKey: .walk)
        try values.encode(ride, forKey: .ride)
        try values.encode(lateGrace, forKey: .lateGrace)
        try values.encode(rides, forKey: .rides)
        try values.encodeIfPresent(change, forKey: .change)
    }
}

extension BusPlan {
    /// The ride on one of the kid's buses from our stop.
    public func ride(on service: String) -> Int { rides[service] ?? ride }

    /// Every way the kid can go: each bus from our stop with its ride, then the bus that changes.
    public var routes: [BusRoute] {
        services.map { BusRoute(service: $0, then: nil, trip: ride(on: $0)) }
            + (change.map { [BusRoute(service: $0.firstBus, then: $0.thenBus, trip: $0.trip)] } ?? [])
    }

    /// Spec "Several buses": a pill toggles its bus on or off; the buses stay in pill order (`order`,
    /// the buses at the stop), any not in it after them.
    public static func toggling(_ service: String, in services: [String], order: [String]) -> [String] {
        var picked = services
        if let index = picked.firstIndex(of: service) {
            picked.remove(at: index)
        } else {
            picked.append(service)
        }
        let rank = { (bus: String) in order.firstIndex(of: bus) ?? order.count }
        return picked.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    /// The plan with the kid's school late grace, which wins over the plan's own (spec "Latest lives
    /// on the school record"); the plan's value stays for a kid with no school times.
    public func graced(by kid: Kid?) -> BusPlan {
        var plan = self
        if let grace = kid?.school?.lateGrace { plan.lateGrace = grace }
        return plan
    }
}

/// One way to the place: a bus that boards at our stop, the bus it changes to (if any) and the
/// minutes from boarding to the place.
public struct BusRoute: Hashable, Sendable {
    public var service: String
    public var then: String?
    public var trip: Int

    public init(service: String, then: String?, trip: Int) {
        self.service = service
        self.then = then
        self.trip = trip
    }
}

/// A bus that changes (spec "C2c"): a first bus from our stop, then a second bus. Nothing is worked
/// out at the change stop: the trip is Ride 1 + Change + Ride 2 as set.
public struct BusChange: Hashable, Sendable {
    public static let defaultChange = 5

    public var firstBus: String
    public var thenBus: String
    public var ride1: Int
    /// "to change buses": the walk and the wait together.
    public var change: Int
    public var ride2: Int

    public init(firstBus: String, thenBus: String, ride1: Int = BusPlan.defaultRide,
                change: Int = BusChange.defaultChange, ride2: Int = BusPlan.defaultRide) {
        self.firstBus = firstBus
        self.thenBus = thenBus
        self.ride1 = ride1
        self.change = change
        self.ride2 = ride2
    }

    public var trip: Int { ride1 + change + ride2 }

    /// A bus number as LTA writes them: digits, then at most one letter ("12", "34A").
    public static func isServiceNumber(_ text: String) -> Bool {
        guard let first = text.first, first.isASCII, first.isNumber, text.count <= 4 else { return false }
        let digits = text.prefix { $0.isASCII && $0.isNumber }
        let rest = text.dropFirst(digits.count)
        return rest.isEmpty || (rest.count == 1 && rest.first!.isASCII && rest.first!.isLetter)
    }
}

extension BusChange: Codable {
    private enum CodingKeys: String, CodingKey {
        case firstBus, thenBus, ride1, change, ride2
        /// Before "Several buses": the walk at the change stop (now the Change minutes).
        case walk
    }

    /// A change saved with a change stop keeps its buses and rides; the walk there becomes Change.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(firstBus: try values.decode(String.self, forKey: .firstBus),
                  thenBus: try values.decode(String.self, forKey: .thenBus),
                  ride1: try values.decode(Int.self, forKey: .ride1),
                  change: try values.decodeIfPresent(Int.self, forKey: .change)
                      ?? values.decodeIfPresent(Int.self, forKey: .walk) ?? BusChange.defaultChange,
                  ride2: try values.decode(Int.self, forKey: .ride2))
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(firstBus, forKey: .firstBus)
        try values.encode(thenBus, forKey: .thenBus)
        try values.encode(ride1, forKey: .ride1)
        try values.encode(change, forKey: .change)
        try values.encode(ride2, forKey: .ride2)
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

    /// One arrival of one of the kid's buses at our stop, with the way it would take.
    public struct Bus: Equatable, Sendable {
        public let arrival: BusArrival
        public let route: BusRoute
        /// The kid can still walk to it (minutes ≥ walk).
        public let isCatchable: Bool
        /// Minutes from now until it reaches the place.
        public var reaches: Int { arrival.minutes + route.trip }
    }

    /// The strip's buses (spec "A2 strip"): every arrival of the kid's buses under 30 min away (and
    /// the chosen one), soonest first.
    public let buses: [Bus]
    /// Among the catchable arrivals, the one that reaches the place first; on a tie, the one at our
    /// stop first.
    public let chosen: Bus?
    /// Minutes until the kid should leave home for the chosen bus.
    public let leaveIn: Int?
    public let status: Status?

    /// The strip shows buses under this many minutes away.
    public static let stripMinutes = 30

    /// - Parameters: `arrivals` all live arrivals at the stop; `minute` now (minutes after
    ///   midnight); `start` the outing's start (arrive-by).
    public init(arrivals: [BusArrival], plan: BusPlan, minute: Int, start: Int) {
        let all = Self.buses(arrivals: arrivals, plan: plan)
        let chosen = all.filter(\.isCatchable).min { ($0.reaches, $0.arrival.minutes) < ($1.reaches, $1.arrival.minutes) }
        self.chosen = chosen
        buses = all.filter { $0.arrival.minutes < Self.stripMinutes || $0 == chosen }
        guard let chosen else {
            leaveIn = nil
            status = .askGrownup
            return
        }
        let leaveIn = chosen.arrival.minutes - plan.walk
        self.leaveIn = leaveIn
        let arrival = minute + chosen.reaches
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

    /// The other buses, soonest first.
    public var others: [Bus] { buses.filter { $0 != chosen } }

    /// Each arrival of a bus the kid takes, with its fastest way (a bus that is both direct and the
    /// first bus of a change goes the faster way), soonest first.
    static func buses(arrivals: [BusArrival], plan: BusPlan) -> [Bus] {
        let routes = plan.routes
        return arrivals.sorted { $0.minutes < $1.minutes }.compactMap { arrival in
            routes.filter { $0.service == arrival.service }.min { $0.trip < $1.trip }.map {
                Bus(arrival: arrival, route: $0, isCatchable: arrival.minutes >= plan.walk)
            }
        }
    }

    /// L1 and L2 (spec): the leave times of the last arrival of any of the kid's buses that still
    /// gets the kid there by the start (L1) and by the start + late grace (L2), at the slide.
    public static func leaveTargets(arrivals: [BusArrival], plan: BusPlan, minute: Int,
                                    start: Int) -> (ideal: Int, latest: Int)? {
        let all = buses(arrivals: arrivals, plan: plan)
        func lastLeave(by deadline: Int) -> Int? {
            all.filter { minute + $0.reaches <= deadline }
                .map { minute + $0.arrival.minutes - plan.walk }
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
