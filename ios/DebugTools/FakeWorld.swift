#if DEBUG
import BusClient
import ComposableArchitecture
import Domain
import SchoolDirectory

/// The outside world tests run in, as plain data and the fakes built from it. One definition for both
/// runs of a journey: the journeys' `World` in Bazel and the app's test mode (`-fpFamily`,
/// `-fpDriver`) on a simulator or the iPad. A stop or school added here reaches both. Fake values only
/// (privacy rule): stop 12345, Example Primary School.
public enum FakeWorld {
    public struct Stop: Equatable, Sendable {
        public var code, name, road: String
        public var buses: [String]

        public init(code: String, name: String, road: String, buses: [String]) {
            self.code = code
            self.name = name
            self.road = road
            self.buses = buses
        }
    }

    public struct School: Equatable, Sendable {
        public var id, name, area: String
        public var start, end: Int
        /// When the hours were checked, `yyyy-MM-dd`.
        public var checked: String

        public init(id: String, name: String, area: String, start: Int, end: Int, checked: String) {
            self.id = id
            self.name = name
            self.area = area
            self.start = start
            self.end = end
            self.checked = checked
        }
    }

    public static let stops = [
        Stop(code: "12345", name: "Example Stop", road: "Example Rd", buses: ["1", "2"]),
        Stop(code: "12346", name: "Example Interchange", road: "Example Ave", buses: ["2", "33"]),
    ]
    /// Every bus number the network knows.
    public static let services = ["1", "2", "33"]
    public static let schools = [
        School(id: "example-primary", name: "Example Primary School", area: "Example Town",
               start: 450, end: 810, checked: "2026-11-09"),
    ]

    /// The bus network and the school list as clients: what a journey's World and test mode install.
    public static func install(_ values: inout DependencyValues, stops: [Stop] = stops,
                               services: [String] = services, schools: [School] = schools) {
        values.bus.stop = { code in
            stops.first { $0.code == code }.map { BusStop(code: $0.code, name: $0.name, road: $0.road) }
        }
        values.bus.searchStops = { text in
            stops.filter { $0.name.localizedCaseInsensitiveContains(text) }
                .map { BusStop(code: $0.code, name: $0.name, road: $0.road) }
        }
        values.bus.arrivals = { code in
            (stops.first { $0.code == code }?.buses ?? []).enumerated().map { index, bus in
                BusArrival(service: bus, minutes: 5 + 2 * index, type: .single)
            }
        }
        values.bus.isService = { services.contains($0) }

        let directory = entries(schools)
        values.schoolDirectory.schools = { directory }
        values.schoolDirectory.calendar = { _, _ in .none }
        values.schoolDirectory.updated = { nil }
        values.schoolDirectory.sources = { [] }
    }

    /// The schools as the app's directory entries.
    public static func entries(_ schools: [School]) -> [SchoolEntry] {
        schools.map { school in
            let checked = school.checked.split(separator: "-").compactMap { Int($0) }
            return SchoolEntry(id: school.id, name: school.name, kind: .moe(.primary), area: school.area,
                               hasPrimary: true, followsMoeTerms: true,
                               hours: SchoolHours(start: school.start, end: school.end,
                                                  checked: Day(year: checked[0], month: checked[1], day: checked[2])),
                               searchKeys: [school.name.lowercased()])
        }
    }
}
#endif
