// Fixture (not compiled): debug-only code is never view code for this rule.
import SwiftUI

struct FixtureDebugView: View {
    var body: some View { Text(name ?? "").opacity(store.isOn ? 1 : 0) }
}
