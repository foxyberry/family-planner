#if DEBUG
import Domain

/// Debug "Fake buses": made-up live arrivals for the kid's own buses, so the morning's live look
/// can be checked at any time-machine time. Each bus comes every 10–12 minutes, the first soon enough
/// to be "too soon" for a 10-minute walk, the next one catchable.
public enum FakeBuses {
    public static func arrivals(services: [String]) -> [BusArrival] {
        let types: [BusType] = [.double, .single, .bendy]
        let buses = services.isEmpty ? ["1"] : services // copy-ok: a made-up bus number
        return buses.enumerated().flatMap { index, service in
            [4, 15, 27].map { minutes in
                BusArrival(service: service, minutes: minutes + 3 * index, type: types[(index + minutes) % types.count])
            }
        }
        .sorted { $0.minutes < $1.minutes }
    }
}
#endif
