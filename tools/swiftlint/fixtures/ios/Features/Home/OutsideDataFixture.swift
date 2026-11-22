// Fixture for outside_data (not compiled): a feature file that is not a *View.swift file.
// Every line marked `bad` must be reported, and no other line.
import SwiftUI

struct OutsideDataFixture {
    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date

    func reads() {
        let calendar = Calendar.current  // bad
        let now = Date()  // bad
        let nowToo = Date.now  // bad
        let locale = Locale.current  // bad
        let model = UIDevice.current.model  // bad
        let bundle = Bundle.main  // bad
        UserDefaults.standard.set(1, forKey: "k")  // bad
        let arguments = ProcessInfo.processInfo.arguments  // bad
        let autoZone = TimeZone.autoupdatingCurrent  // bad
        let fixed = Date(timeIntervalSince1970: 0)
        let fromClient = date.now
        let label = "Date() and Calendar.current in a string"
        // Never use Calendar.current or Date() here.
    }
}

struct FixturePanel: View {
    @Dependency(\.date) var date  // bad
    var body: some View { Text("Panel") }
}
