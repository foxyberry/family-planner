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
    /// The buses that change (board C2c), each one more equal pill of the kid, in the order added.
    public var changes: [BusChange]

    public init(kid: Kid.ID, event: EventRef = .school, stop: String, services: [String],
                walk: Int = BusPlan.defaultWalk, ride: Int = BusPlan.defaultRide,
                lateGrace: Int = BusPlan.defaultLateGrace, rides: [String: Int] = [:], changes: [BusChange] = []) {
        self.kid = kid
        self.event = event
        self.stop = stop
        self.services = services
        self.walk = walk
        self.ride = ride
        self.lateGrace = lateGrace
        self.rides = rides
        self.changes = changes
    }
}

extension BusPlan: Codable {
    private enum CodingKeys: String, CodingKey {
        case kid, event, stop, services, walk, ride, lateGrace, rides, changes
        /// Before "Several buses": the 2nd bus's own ride.
        case secondRide
        /// Before several buses that change (2026-11-21): the one bus that changes.
        case change
    }

    /// Plans stored before routes were per event are the kid's School route. Plans stored before
    /// "Several buses" keep their buses: the 1st and 2nd become two equal buses, each with its own
    /// ride (the 2nd's "Ride 2nd"), and a changing 2nd becomes the bus that changes. A plan with one
    /// bus that changes keeps it as the only one in `changes`.
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
                  changes: try values.decodeIfPresent([BusChange].self, forKey: .changes)
                      ?? values.decodeIfPresent(BusChange.self, forKey: .change).map { [$0] } ?? [])
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
        try values.encode(changes, forKey: .changes)
    }
}

extension BusPlan {
    /// The ride on one of the kid's buses from our stop.
    public func ride(on service: String) -> Int { rides[service] ?? ride }

    /// Every way the kid can go: each bus from our stop with its ride, then each bus that changes,
    /// one way per first bus (its Ride 1 + Change + Ride 2).
    public var routes: [BusRoute] {
        services.map { BusRoute(service: $0, then: nil, trip: ride(on: $0)) } + changes.flatMap(\.routes)
    }

    /// Spec "Several buses → Settings value": every bus number of the kid once, in pill order (the
    /// direct buses, then each bus that changes by its first buses).
    public var numbers: [String] {
        var numbers: [String] = []
        for route in routes where !numbers.contains(route.service) { numbers.append(route.service) }
        return numbers
    }

    /// The route's pills in pill order (C2, S3, the A2 legend): each direct bus, then each bus that
    /// changes by its first buses.
    public var pills: [BusPill] {
        services.map { BusPill(buses: [$0], then: nil) } + changes.map { BusPill(buses: $0.firstBuses, then: $0.thenBus) }
    }

    /// The A2 legend's faded plates: the pills other than `route` (the chosen way). A direct bus drops
    /// its own pill; a way through a bus that changes drops its first bus from that pill, and the
    /// pill once no first bus is left ("12 · 34 → 33" with 12 chosen leaves "34 → 33").
    public func pills(besides route: BusRoute?) -> [BusPill] {
        guard let route else { return pills }
        guard let then = route.then else { return pills.filter { $0 != BusPill(buses: [route.service], then: nil) } }
        let index = changes.firstIndex { $0.thenBus == then && $0.firstBuses.contains(route.service)
            && $0.trip(from: route.service) == route.trip }
            ?? changes.firstIndex { $0.thenBus == then && $0.firstBuses.contains(route.service) }
        return services.map { BusPill(buses: [$0], then: nil) } + changes.enumerated().compactMap { offset, change in
            let buses = offset == index ? change.firstBuses.filter { $0 != route.service } : change.firstBuses
            return buses.isEmpty ? nil : BusPill(buses: buses, then: change.thenBus)
        }
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

/// One pill of a route: a direct bus (`then` nil), or a bus that changes by its first buses.
public struct BusPill: Hashable, Sendable {
    public var buses: [String]
    public var then: String?

    public init(buses: [String], then: String?) {
        self.buses = buses
        self.then = then
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

/// A bus that changes (spec "C2c"): one or more first buses from our stop to the change (each with
/// its own Ride 1), then one second bus. Nothing is worked out at the change stop: a trip is that
/// first bus's Ride 1 + Change + Ride 2 as set.
public struct BusChange: Hashable, Sendable {
    public static let defaultChange = 5

    /// The first buses, in pill order (the buses at our stop).
    public var firstBuses: [String]
    /// Each first bus's Ride 1; only the first buses keep one.
    public var rides1: [String: Int]
    public var thenBus: String
    /// "to change buses": the walk and the wait together.
    public var change: Int
    public var ride2: Int

    public init(firstBuses: [String], thenBus: String, rides1: [String: Int] = [:],
                change: Int = BusChange.defaultChange, ride2: Int = BusPlan.defaultRide) {
        self.firstBuses = firstBuses
        self.rides1 = rides1.filter { firstBuses.contains($0.key) }
        self.thenBus = thenBus
        self.change = change
        self.ride2 = ride2
    }

    /// One first bus with its Ride 1.
    public init(firstBus: String, thenBus: String, ride1: Int = BusPlan.defaultRide,
                change: Int = BusChange.defaultChange, ride2: Int = BusPlan.defaultRide) {
        self.init(firstBuses: [firstBus], thenBus: thenBus, rides1: [firstBus: ride1], change: change, ride2: ride2)
    }

    /// Ride 1 on one of the first buses.
    public func ride1(on bus: String) -> Int { rides1[bus] ?? BusPlan.defaultRide }

    /// From boarding `bus` at our stop to the place.
    public func trip(from bus: String) -> Int { ride1(on: bus) + change + ride2 }

    /// One way per first bus, in pill order.
    public var routes: [BusRoute] {
        firstBuses.map { BusRoute(service: $0, then: thenBus, trip: trip(from: $0)) }
    }

    /// The first buses as one name ("12 · 34"), joined by `separator`.
    public func firstBusesName(separator: String) -> String { firstBuses.joined(separator: separator) }

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
        case firstBuses, rides1, thenBus, change, ride2
        /// Before several first buses (2026-11-21): the one first bus and its Ride 1.
        case firstBus, ride1
        /// Before "Several buses": the walk at the change stop (now the Change minutes).
        case walk
    }

    /// A change saved with one first bus keeps it as the only first bus with its Ride 1; one saved
    /// with a change stop keeps its buses and rides, and the walk there becomes Change.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let firstBuses: [String]
        let rides1: [String: Int]
        if let buses = try values.decodeIfPresent([String].self, forKey: .firstBuses) {
            firstBuses = buses
            rides1 = try values.decodeIfPresent([String: Int].self, forKey: .rides1) ?? [:]
        } else {
            let bus = try values.decode(String.self, forKey: .firstBus)
            firstBuses = [bus]
            rides1 = [bus: try values.decode(Int.self, forKey: .ride1)]
        }
        self.init(firstBuses: firstBuses, thenBus: try values.decode(String.self, forKey: .thenBus), rides1: rides1,
                  change: try values.decodeIfPresent(Int.self, forKey: .change)
                      ?? values.decodeIfPresent(Int.self, forKey: .walk) ?? BusChange.defaultChange,
                  ride2: try values.decode(Int.self, forKey: .ride2))
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(firstBuses, forKey: .firstBuses)
        try values.encode(rides1, forKey: .rides1)
        try values.encode(thenBus, forKey: .thenBus)
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

    /// Each arrival of a bus the kid takes, with its fastest way (a bus that is direct and the first
    /// bus of a change, or a first bus of several changes, is one trip the faster way), soonest first.
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
