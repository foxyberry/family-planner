import AppCore
import AppSettings
import BusClient
import ComposableArchitecture
import DeviceLook
import Domain
import Foundation
import HolidayProvider
import ParentAuthClient
import SchoolDirectory
import ScheduleStore

/// The outside world a journey runs in, as plain data (README.md): the time, the bus network, the
/// school list and the family on the iPad. Nothing here is Swift-only on purpose, so the same
/// journey can later be replayed from a neutral script on another platform. Fake values only
/// (privacy rule): Kid A and Kid B, stop 12345.
struct WorldData: Sendable {
    struct Stop: Sendable { var code, name, road: String; var buses: [String] }
    struct School: Sendable { var id, name, area: String; var start, end: Int; var checked: String }
    struct Route: Sendable { var kid: String; var stop: String; var buses: [String]; var walk, ride: Int }

    /// Local time, ISO 8601 without a zone, and the zone it is in.
    var now = "2026-11-10T07:30"
    var timeZone = "Asia/Singapore"
    var stops = [Stop(code: "12345", name: "Example Stop", road: "Example Rd", buses: ["1", "2"]),
                 Stop(code: "12346", name: "Example Interchange", road: "Example Ave", buses: ["2", "33"])]
    /// Every bus number LTA knows.
    var services = ["1", "2", "33"]
    var schools = [School(id: "example-primary", name: "Example Primary School", area: "Example Town",
                          start: 450, end: 810, checked: "2026-11-09")]
    /// "empty" (a new iPad) or "sample" (Kid A and Kid B with this week's items).
    var family = "empty"
    /// Bus routes saved for the sample kids ("Kid A", "Kid B").
    var routes: [Route] = []
    /// What Face ID answers: "success", "notRecognised", "cancelled", "notAvailable", "lockedOut".
    var faceID = "success"

    /// Tuesday 10 Nov 2026, 7:30 am in Singapore: not a holiday (Monday the 9th is Deepavali observed).
    static let standard = WorldData()
}

/// The dependencies a journey's store runs with, built from `WorldData`. A client the world doesn't
/// fake stays unimplemented, so any I/O a journey didn't expect fails the test, and time moves only
/// by the test clock: no sleeps.
final class World: Sendable {
    let data: WorldData
    let calendar: Calendar
    let now: Date
    /// What the store holds; journeys read it after a save.
    let family: LockIsolated<ScheduleSnapshot>
    let settings = LockIsolated(AppSettings.defaults)
    let auth: LockIsolated<ParentAuthOutcome>
    let clock = TestClock()

    var today: Day { Day(now, calendar: calendar) }

    init(_ data: WorldData = .standard) {
        self.data = data
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: data.timeZone)!
        self.calendar = calendar
        let parts = data.now.split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        let day = Day(year: parts[0], month: parts[1], day: parts[2])
        now = day.date(minute: parts[3] * 60 + parts[4], calendar: calendar)
        var snapshot = data.family == "sample"
            ? ScheduleSnapshot.sampleFamily(today: day, calendar: calendar)
            : ScheduleSnapshot(kids: [], routines: [], items: [])
        let kids = snapshot.kids
        snapshot.busPlans = data.routes.compactMap { route in
            kids.first { $0.name == route.kid }.map {
                BusPlan(kid: $0.id, stop: route.stop, services: route.buses, walk: route.walk, ride: route.ride)
            }
        }
        let start = snapshot  // LockIsolated's Sendable autoclosure can't capture a var
        family = LockIsolated(start)
        let outcomes: [String: ParentAuthOutcome] = [
            "success": .success, "notRecognised": .notRecognised, "cancelled": .cancelled,
            "notAvailable": .notAvailable, "lockedOut": .lockedOut,
        ]
        auth = LockIsolated(outcomes[data.faceID] ?? .success)
    }

    /// A school of the list as the app's directory entry.
    func school(_ id: String) -> SchoolEntry? { directory.first { $0.id == id } }

    private var directory: [SchoolEntry] {
        data.schools.map { school in
            let checked = school.checked.split(separator: "-").compactMap { Int($0) }
            return SchoolEntry(id: school.id, name: school.name, kind: .moe(.primary), area: school.area,
                               hasPrimary: true, followsMoeTerms: true,
                               hours: SchoolHours(start: school.start, end: school.end,
                                                  checked: Day(year: checked[0], month: checked[1], day: checked[2])),
                               searchKeys: [school.name.lowercased()])
        }
    }

    func install(_ values: inout DependencyValues) {
        values.calendar = calendar
        values.date.now = now
        values.uuid = .incrementing
        values.continuousClock = clock

        let family = family
        values.scheduleStore.load = { family.value }
        values.scheduleStore.replaceFamily = { new in family.setValue(new) }
        values.scheduleStore.saveBusPlan = { plan in
            family.withValue { $0.busPlans.removeAll { $0.kid == plan.kid && $0.event == plan.event }; $0.busPlans.append(plan) }
        }
        values.scheduleStore.saveKid = { kid in
            family.withValue { snapshot in
                if let index = snapshot.kids.firstIndex(where: { $0.id == kid.id }) {
                    snapshot.kids[index] = kid
                } else {
                    snapshot.kids.append(kid)  // G6a "Add a child"
                }
            }
        }
        values.scheduleStore.saveRoutine = { routine in
            family.withValue { snapshot in
                snapshot.routines.removeAll { $0.kid == routine.kid && $0.dayType == routine.dayType && $0.from == routine.from }
                snapshot.routines.append(routine)
            }
        }
        values.scheduleStore.saveMissions = { kid, missions in
            family.withValue { $0.missions.removeAll { $0.kid == kid }; $0.missions += missions }
        }

        let stops = data.stops, services = data.services
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

        let directory = directory
        values.schoolDirectory.schools = { directory }
        values.schoolDirectory.calendar = { _, _ in .none }
        values.schoolDirectory.updated = { nil }
        values.schoolDirectory.sources = { [] }
        values.holidays.holidays = { _ in [] }
        values.deviceLook.isDark = { false }

        let settings = settings
        values.appSettings.load = { settings.value }
        values.appSettings.save = { settings.setValue($0) }

        let auth = auth
        values.parentAuth.biometry = { .faceID }
        values.parentAuth.authenticate = { _ in auth.value }
    }

    /// The root store in this world, starting from `state`. Journeys check the State a person
    /// would see after each step, so the store is not exhaustive about effects they don't name.
    @MainActor
    func store(_ state: AppFeature.State = AppFeature.State()) -> TestStoreOf<AppFeature> {
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: { self.install(&$0) }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
