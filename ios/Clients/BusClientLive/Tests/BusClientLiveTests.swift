import BusClient
import BusClientLive
import Domain
import XCTest

/// LTA answers parsed from made-up responses (stop "00000", buses "1" and "2"; privacy rule).
final class BusClientLiveTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-10T06:52:00+08:00")!

    func testArrivalsBecomeMinutesFromNow() throws {
        let json = """
        {"BusStopCode":"00000","Services":[
          {"ServiceNo":"1","NextBus":{"EstimatedArrival":"2026-11-10T06:56:30+08:00","Type":"SD"},
           "NextBus2":{"EstimatedArrival":"2026-11-10T07:20:10+08:00","Type":"DD"},
           "NextBus3":{"EstimatedArrival":"","Type":""}},
          {"ServiceNo":"2","NextBus":{"EstimatedArrival":"2026-11-10T06:51:00+08:00","Type":"BD"}}
        ]}
        """
        let arrivals = try LTA.arrivals(from: Data(json.utf8), now: now)
        XCTAssertEqual(arrivals, [
            BusArrival(service: "2", minutes: 0, type: .bendy),
            BusArrival(service: "1", minutes: 4, type: .single),
            BusArrival(service: "1", minutes: 28, type: .double),
        ])
    }

    /// Minutes count from LTA's clock: the HTTP Date header parses to the server's time.
    func testServerDateHeader() {
        let date = LTA.httpDate("Tue, 10 Nov 2026 07:00:00 GMT")
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_794_294_000))
        XCTAssertNil(LTA.httpDate("not a date"))
    }

    func testStopsPage() throws {
        let json = #"{"value":[{"BusStopCode":"00000","RoadName":"Example Rd","Description":"Example Stop"}]}"#
        let page = try LTA.stops(from: Data(json.utf8))
        XCTAssertEqual(page.first?.code, "00000")
        XCTAssertEqual(page.first?.name, "Example Stop")
    }

    /// Families know the stop's name, not its code (user, 2026-11-09). Made-up stops only.
    func testSearchByNameRoadOrCode() {
        let stops = [BusStop(code: "11111", name: "Opp Example Park", road: "Sample Ave"),
                     BusStop(code: "22222", name: "Example Pr Sch", road: "Sample Ave"),
                     BusStop(code: "33333", name: "Blk 12", road: "Other Rd")]
        XCTAssertEqual(LTA.search("example", in: stops).map(\.code), ["22222", "11111"])
        XCTAssertEqual(LTA.search("park sample", in: stops).map(\.code), ["11111"])
        XCTAssertEqual(LTA.search("other", in: stops).map(\.code), ["33333"])
        XCTAssertEqual(LTA.search("333", in: stops).map(\.code), ["33333"])
        XCTAssertEqual(LTA.search("  ", in: stops), [])
    }
}
