import BusClient
import Dependencies
import Domain
import Foundation

extension BusClient {
    /// LTA DataMall: BusArrival v3 for live times and BusStops (paged) for a stop's name, with the
    /// key built into the app (`nil`: every call throws `LTA.Failure.noKey`). The current time is
    /// read at call time from `\.date`.
    public static func live(key: String?, session: URLSession = .shared) -> Self {
        Self(
            arrivals: { stop in
                guard let key else { throw LTA.Failure.noKey }
                @Dependency(\.date) var date
                let data = try await LTA.get(LTA.arrivalPath, query: [(LTA.stopParameter, stop)], key: key,
                                             session: session)
                return try LTA.arrivals(from: data, now: date.now)
            },
            stop: { code in
                guard let key else { throw LTA.Failure.noKey }
                return try await stops.all(key: key, session: session).first { $0.code == code }
            },
            searchStops: { text in
                guard let key else { throw LTA.Failure.noKey }
                return LTA.search(text, in: try await stops.all(key: key, session: session))
            }
        )
    }
}

/// The whole stop list (about 5,200 stops, 500 a page), fetched once per app run.
private let stops = StopList()

private actor StopList {
    private var cached: [BusStop]?

    func all(key: String, session: URLSession) async throws -> [BusStop] {
        if let cached { return cached }
        var list: [BusStop] = []
        for skip in stride(from: 0, to: 6000, by: 500) {
            let data = try await LTA.get(LTA.stopsPath, query: [(LTA.skipParameter, "\(skip)")], key: key,
                                         session: session)
            let page = try LTA.stops(from: data)
            list += page
            if page.count < 500 { break }
        }
        cached = list
        return list
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
        /// No key is built into this app (no local config).
        public static let noKey = Failure(status: 0)
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
    public static func stops(from data: Data) throws -> [BusStop] {
        try JSONDecoder().decode(StopsAnswer.self, from: data).value
            .map { BusStop(code: $0.code, name: $0.description, road: $0.road ?? "") }
    }

    /// Stops whose name or road holds every word of `text` (any case), names starting with the
    /// first word first; a run of digits matches the start of the code. At most `limit`.
    public static func search(_ text: String, in stops: [BusStop], limit: Int = 8) -> [BusStop] {
        let words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let matches = stops.filter { stop in
            let haystack = (stop.name + " " + stop.road).lowercased()
            return words.allSatisfy { word in
                haystack.contains(word) || (word.allSatisfy(\.isNumber) && stop.code.hasPrefix(word))
            }
        }
        return matches.sorted { a, b in
            let aStarts = a.name.lowercased().hasPrefix(words[0]), bStarts = b.name.lowercased().hasPrefix(words[0])
            return aStarts != bStarts ? aStarts : a.name < b.name
        }
        .prefix(limit).map { $0 }
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
        let road: String?
        enum CodingKeys: String, CodingKey { // copy-ok: JSON keys
            case code = "BusStopCode", description = "Description", road = "RoadName" // copy-ok: JSON keys
        }
    }
}
