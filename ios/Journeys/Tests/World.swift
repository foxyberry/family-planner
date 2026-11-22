import AppCore
import AppSettings
import BusClient
import ComposableArchitecture
import DebugTools
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
public struct WorldData: Sendable {
    public typealias Stop = FakeWorld.Stop
    public typealias School = FakeWorld.School
    public struct Route: Sendable {
        public var kid: String
        public var stop: String
        public var buses: [String]
        public var walk, ride: Int
        public init(kid: String, stop: String, buses: [String], walk: Int, ride: Int) {
            self.kid = kid; self.stop = stop; self.buses = buses; self.walk = walk; self.ride = ride
        }
    }

    /// Local time, ISO 8601 without a zone, and the zone it is in.
    public var now = "2026-11-10T07:30"
    public var timeZone = "Asia/Singapore"
    public var stops = FakeWorld.stops
    /// Every bus number LTA knows.
    public var services = FakeWorld.services
    public var schools = FakeWorld.schools
    /// "empty" (a new iPad) or "sample" (Kid A and Kid B with this week's items).
    public var family = "empty"
    /// Bus routes saved for the sample kids ("Kid A", "Kid B").
    public var routes: [Route] = []
    /// What Face ID answers: "success", "notRecognised", "cancelled", "notAvailable", "lockedOut".
    public var faceID = "success"
    /// Public holidays, "yyyy-mm-dd" to the holiday's name (none unless a journey sets them).
    public var holidays: [String: String] = [:]
    /// School breaks every kid's school follows: name, first and last day ("yyyy-mm-dd").
    public var breaks: [Break] = []

    public struct Break: Sendable {
        public var name, from, to: String
        public init(name: String, from: String, to: String) {
            self.name = name; self.from = from; self.to = to
        }
    }

    /// Tuesday 10 Nov 2026, 7:30 am in Singapore: not a holiday (Monday the 9th is Deepavali observed).
    public static let standard = WorldData()

    public init() {}
}

/// The dependencies a journey's store runs with, built from `WorldData`. A client the world doesn't
/// fake stays unimplemented, so any I/O a journey didn't expect fails the test, and time moves only
/// by the test clock: no sleeps.
public final class World: Sendable {
    public let data: WorldData
    public let calendar: Calendar
    public let now: Date
    /// What the store holds; journeys read it after a save.
    public let family: LockIsolated<ScheduleSnapshot>
    public let settings = LockIsolated(AppSettings.defaults)
    /// A2's ticked missions and slides.
    public let marks = LockIsolated<[WindowMissions]>([])
    public let slides = LockIsolated<[OutingSlide]>([])
    /// How many times the app has loaded the family from the store.
    public let loads = LockIsolated(0)
    public let auth: LockIsolated<ParentAuthOutcome>
    public let clock = TestClock()

    public var today: Day { Day(now, calendar: calendar) }

    public init(_ data: WorldData = .standard) {
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
    public func school(_ id: String) -> SchoolEntry? { directory.first { $0.id == id } }

    private var directory: [SchoolEntry] { FakeWorld.entries(data.schools) }

    /// "2026-11-09" as a day.
    static func day(_ text: String) -> Day? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? Day(year: parts[0], month: parts[1], day: parts[2]) : nil
    }

    public func install(_ values: inout DependencyValues) {
        values.calendar = calendar
        values.date.now = now
        values.uuid = .incrementing
        values.continuousClock = clock

        let family = family, loads = loads
        values.scheduleStore.load = { loads.withValue { $0 += 1 }; return family.value }
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
        values.scheduleStore.saveAll = { items in
            family.withValue { snapshot in
                for item in items {
                    snapshot.items.removeAll { $0.id == item.id }
                    snapshot.items.append(item)
                }
            }
        }
        values.scheduleStore.delete = { id in family.withValue { $0.items.removeAll { $0.id == id } } }
        values.scheduleStore.saveMissions = { kid, missions in
            family.withValue { $0.missions.removeAll { $0.kid == kid }; $0.missions += missions }
        }
        // A2's marks and slides, kept like the store keeps them.
        let marks = marks, slides = slides
        values.scheduleStore.windowMissions = { kid, date, window in
            marks.value.first { $0.kid == kid && $0.date == date && $0.window == window }
                ?? WindowMissions(kid: kid, date: date, window: window)
        }
        values.scheduleStore.saveWindowMissions = { new in
            marks.withValue { list in
                list.removeAll { $0.kid == new.kid && $0.date == new.date && $0.window == new.window }
                list.append(new)
            }
        }
        values.scheduleStore.slides = { kid, date in slides.value.filter { $0.kid == kid && $0.date == date } }
        values.scheduleStore.saveSlide = { new in
            slides.withValue { list in
                list.removeAll { $0.kid == new.kid && $0.date == new.date && $0.outing == new.outing }
                list.append(new)
            }
        }

        FakeWorld.install(&values, stops: data.stops, services: data.services, schools: data.schools)
        let holidays = data.holidays.compactMap { date, name in Self.day(date).map { Holiday(day: $0, name: name) } }
            .sorted { $0.day < $1.day }
        values.holidays.holidays = { year in holidays.filter { $0.day.year == year } }
        if !data.breaks.isEmpty {
            var breaks: [Day: String] = [:]
            for entry in data.breaks {
                guard var day = Self.day(entry.from), let last = Self.day(entry.to) else { continue }
                while day <= last {
                    breaks[day] = breaks[day] ?? entry.name
                    day = day.adding(days: 1, calendar: calendar)
                }
            }
            let year = SchoolCalendar(closed: Set(breaks.keys), breaks: breaks)
            values.schoolDirectory.calendar = { _, _ in year }
        }
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
    public func store(_ state: AppFeature.State = AppFeature.State()) -> TestStoreOf<AppFeature> {
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: { self.install(&$0) }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
