import ComposableArchitecture
import Domain
import Foundation
import Grownup
import Localization
import Strings
import XCTest

/// The shared grown-up header gets its words from each screen's State.
final class GrownupWordsTests: XCTestCase {
    private let kid = SeedData.kidA.id
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func states() -> [any GrownupWords] {
        let calendar = Calendar(identifier: .gregorian)
        return [
            AddChildFeature.State(today: tuesday, takenColours: []),
            BusSettingsFeature.State(kid: kid),
            ChangeBusesFeature.State(ourStop: StopSearchFeature.State(), changes: [], index: nil),
            DataSourcesFeature.State(),
            MissionEditorFeature.State(kid: kid),
            OurDayFeature.State(kid: kid, today: tuesday, calendar: calendar),
            SchoolEditorFeature.State(kid: kid, today: tuesday, calendar: calendar),
            SettingsFeature.State(),
        ]
    }

    func testEveryScreenGivesTheHeaderWords() {
        for state in states() {
            XCTAssertEqual(state.headerCaption, "Grown-ups only")
        }
    }

    func testTheWordsComeFromTheInjectedLocalizer() {
        let keyed = withDependencies { $0.localizer = .keys } operation: { states() }
        for state in keyed {
            XCTAssertEqual(state.headerCaption, "grownup.caption")
        }
    }
}
