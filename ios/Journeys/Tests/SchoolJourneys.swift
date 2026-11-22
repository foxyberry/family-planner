import AppCore
import ComposableArchitecture
import Domain
import Grownup
import JourneyWorld
import XCTest

/// G4 · Edit School from Settings (spec G5 "What Settings shows meanwhile"): a School hours change
/// from a later day waits beside today's hours, shows under Hours, and can be cancelled.
@MainActor
final class SchoolJourneys: XCTestCase {
    /// Settings → Hours → G4: a new end saved from tomorrow keeps today's hours; Hours then shows
    /// "From 11 Nov" with the new hours. That row opens G4 on the waiting hours, and "Cancel this
    /// change" asks first, then takes it back: the row is gone and tomorrow's clock keeps today's hours.
    func testAHoursChangeFromALaterDayWaitsAndCanBeCancelled() async throws {
        var data = WorldData.standard
        data.family = "sample"
        let world = World(data)
        let tomorrow = world.today.adding(days: 1, calendar: world.calendar)
        var start = AppFeature.State()
        start.path.append(.settings(SettingsFeature.State(kid: SeedData.kidA.id)))
        let store = world.store(start)
        let settings = store.state.path.ids[0]
        await store.send(.path(.element(id: settings, action: .settings(.task))))
        await store.receive(\.path[id: settings].settings.loaded)
        XCTAssertEqual(schoolRows(store, settings).map(\.key), ["School", "Hours"])

        // Hours › opens G4 on today's hours; School ends at 2:30 pm from tomorrow.
        await store.send(.path(.element(id: settings, action: .settings(.schoolRowTapped))))
        let editor = try XCTUnwrap(store.state.path.ids.last)
        await store.send(.path(.element(id: editor, action: .schoolEditor(.task))))
        await store.receive(\.path[id: editor].schoolEditor.loaded)
        XCTAssertEqual(school(store, editor)?.endLabel, "3:00 pm")
        let end = world.today.date(minute: 870, calendar: world.calendar)
        await store.send(.path(.element(id: editor, action: .schoolEditor(.endPicked(end)))))
        await store.send(.path(.element(id: editor, action: .schoolEditor(.saveTapped))))
        XCTAssertEqual(school(store, editor)?.fromWhenTabs.map(\.1), ["Today", "Tomorrow", "Date"])
        await store.send(.path(.element(id: editor, action: .schoolEditor(.fromWhenPicked(.next)))))
        await store.send(.path(.element(id: editor, action: .schoolEditor(.fromWhenSaveTapped))))
        await store.receive(\.path[id: editor].schoolEditor.delegate.finished)
        await store.finish()
        await store.skipReceivedActions()

        // Back on Settings: today's hours, and the waiting change under them.
        XCTAssertEqual(store.state.path.count, 1)
        let rows = schoolRows(store, settings)
        XCTAssertEqual(rows.map(\.key), ["School", "Hours", "From 11 Nov"])
        XCTAssertEqual(rows[1].value, "Mon–Fri · 7:30 am – 3:00 pm")
        XCTAssertEqual(rows[2].value, "Mon–Fri · 7:30 am – 2:30 pm")
        XCTAssertEqual(schoolEnd(world, on: world.today), 900, "today's clock keeps today's hours")
        XCTAssertEqual(schoolEnd(world, on: tomorrow), 870)

        // "From 11 Nov ›" opens G4 on the waiting hours, with "Cancel this change".
        await store.send(.path(.element(id: settings, action: .settings(.waitingHoursRowTapped))))
        let waiting = try XCTUnwrap(store.state.path.ids.last)
        await store.send(.path(.element(id: waiting, action: .schoolEditor(.task))))
        await store.receive(\.path[id: waiting].schoolEditor.loaded)
        XCTAssertEqual(school(store, waiting)?.endLabel, "2:30 pm")
        XCTAssertEqual(school(store, waiting)?.cancelChangeTitle, "Cancel this change")
        await store.send(.path(.element(id: waiting, action: .schoolEditor(.cancelChangeTapped))))
        XCTAssertEqual(school(store, waiting)?.cancelConfirmTitle, "Cancel the change from 11 Nov?")
        await store.send(.path(.element(id: waiting, action: .schoolEditor(.cancelConfirmed))))
        await store.receive(\.path[id: waiting].schoolEditor.delegate.finished)
        await store.finish()
        await store.skipReceivedActions()

        // Gone: no "From" row, nothing waits, and tomorrow's clock is as it was.
        XCTAssertEqual(schoolRows(store, settings).map(\.key), ["School", "Hours"])
        XCTAssertNil(world.family.value.kids.first?.pendingHours)
        XCTAssertEqual(world.family.value.kids.first?.school?.end, 900)
        XCTAssertEqual(schoolEnd(world, on: tomorrow), 900)
        XCTAssertEqual(world.family.value.routines, SeedData.routines, "no template was ever written for it")
    }

    private func schoolRows(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> [SettingsRow] {
        guard case let .settings(state)? = store.state.path[id: id] else { return [] }
        return state.sections.first { $0.title == "School" }?.rows ?? []
    }

    private func school(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> SchoolEditorFeature.State? {
        guard case let .schoolEditor(state)? = store.state.path[id: id] else { return nil }
        return state
    }

    /// Where School ends on Kid A's weekday template that day, as the store's family reads it by date.
    private func schoolEnd(_ world: World, on day: Day) -> Int? {
        let family = world.family.value
        let routines = family.kids.first { $0.id == SeedData.kidA.id }?.readingWaitingHours(family.routines) ?? []
        return DayPlanner.template(for: SeedData.kidA.id, on: day, routines: routines, holidays: [],
                                   calendar: world.calendar)?.blocks.first { $0.kind == .school }?.end
    }
}
