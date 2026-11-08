import BusClient
import Dependencies
import Domain
import Foundation

extension BusClient {
    /// LTA DataMall: BusArrival v3 for live times and BusStops (paged) for a stop's name. The key
    /// comes from the caller (the Keychain); the current time is read at call time from `\.date`.
    public static func live(session: URLSession = .shared) -> Self {
        Self(
            arrivals: { stop, key in
                @Dependency(\.date) var date
                let data = try await LTA.get(LTA.arrivalPath, query: [(LTA.stopParameter, stop)], key: key,
                                             session: session)
                return try LTA.arrivals(from: data, now: date.now)
            },
            stopName: { stop, key in
                // The stop list comes 500 at a time; Singapore has about 5,200 stops.
                for skip in stride(from: 0, to: 6000, by: 500) {
                    let data = try await LTA.get(LTA.stopsPath, query: [(LTA.skipParameter, "\(skip)")], key: key,
                                                 session: session)
                    let page = try LTA.stops(from: data)
                    if let match = page.first(where: { $0.code == stop }) { return match.name }
                    if page.count < 500 { return nil }
                }
                return nil
            }
        )
    }
}

/// LTA DataMall calls and parsing, kept apart so tests can feed made-up responses.
public enum LTA {
    static let base = "https://datamall2.mytransport.sg/ltaodataservice/" // copy-ok: API host
    static let arrivalPath = "v3/BusArrival" // copy-ok: API path
    static let stopsPath = "BusStops" // copy-ok: API path
    static let stopParameter = "BusStopCode" // copy-ok: API parameter
    static let skipParameter = "$skip" // copy-ok: API parameter

    public struct Failure: Error, Equatable {
        public let status: Int
    }

    static func get(_ path: String, query: [(String, String)], key: String, session: URLSession) async throws -> Data {
        var components = URLComponents(string: base + path)
        components?.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components?.url else { throw Failure(status: 0) }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(key, forHTTPHeaderField: "AccountKey") // copy-ok: LTA header name
        request.setValue("application/json", forHTTPHeaderField: "accept") // copy-ok: HTTP header
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure(status: status) }
        return data
    }

    /// Every upcoming bus in a BusArrival v3 answer, minutes from `now` (rounded down, never < 0).
    public static func arrivals(from data: Data, now: Date) throws -> [BusArrival] {
        let answer = try JSONDecoder().decode(ArrivalAnswer.self, from: data)
        let parser = ISO8601DateFormatter()
        return answer.services.flatMap { service in
            [service.next, service.next2, service.next3].compactMap { bus -> BusArrival? in
                guard let bus, let at = parser.date(from: bus.estimatedArrival) else { return nil }
                let minutes = max(0, Int((at.timeIntervalSince(now) / 60).rounded(.down)))
                return BusArrival(service: service.number, minutes: minutes, type: busType(bus.type))
            }
        }
        .sorted { $0.minutes < $1.minutes }
    }

    /// One page of the BusStops list.
    public static func stops(from data: Data) throws -> [(code: String, name: String)] {
        try JSONDecoder().decode(StopsAnswer.self, from: data).value.map { ($0.code, $0.description) }
    }

    /// DD double deck, BD bendy, SD (or anything else) single deck.
    static func busType(_ code: String) -> BusType {
        switch code {
        case "DD": .double // copy-ok: LTA code
        case "BD": .bendy // copy-ok: LTA code
        default: .single
        }
    }

    private struct ArrivalAnswer: Decodable {
        let services: [Service]
        enum CodingKeys: String, CodingKey { case services = "Services" } // copy-ok: JSON key
    }

    private struct Service: Decodable {
        let number: String
        let next: Bus?
        let next2: Bus?
        let next3: Bus?
        enum CodingKeys: String, CodingKey {
            case number = "ServiceNo", next = "NextBus", next2 = "NextBus2", next3 = "NextBus3" // copy-ok: JSON keys
        }
    }

    private struct Bus: Decodable {
        let estimatedArrival: String
        let type: String
        enum CodingKeys: String, CodingKey { case estimatedArrival = "EstimatedArrival", type = "Type" } // copy-ok: JSON keys
    }

    private struct StopsAnswer: Decodable {
        let value: [Stop]
    }

    private struct Stop: Decodable {
        let code: String
        let description: String
        enum CodingKeys: String, CodingKey { case code = "BusStopCode", description = "Description" } // copy-ok: JSON keys
    }
}
