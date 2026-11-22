// Fixture (not compiled): tests, snapshot tests, ios/App and ios/DebugTools are never view code.
import SwiftUI

struct FixtureTestView: View {
    var body: some View { Text(name ?? "").opacity(store.isOn ? 1 : 0) }
}

enum FixtureTestReads {
    static let calendar = Calendar.current
}

struct FixtureTestFrames: View {
    var body: some View { Text("t").frame(width: 112).offset(x: 4) }
}
