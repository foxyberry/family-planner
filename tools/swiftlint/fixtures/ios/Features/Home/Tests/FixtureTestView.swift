// Fixture (not compiled): tests, snapshot tests, ios/App and ios/DebugTools are never view code.
import SwiftUI

struct FixtureTestView: View {
    var body: some View { Text(name ?? "").opacity(store.isOn ? 1 : 0) }
}
