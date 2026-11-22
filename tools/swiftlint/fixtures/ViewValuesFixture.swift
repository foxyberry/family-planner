// Fixture for `scripts/swiftlint.sh --self-test` (not compiled): every line marked `bad` must be
// reported by view_values, and no other line.
import SwiftUI

struct FixtureView: View {
    var body: some View {
        Text(store.label ?? "")  // bad
        Rectangle().opacity(store.canUndo ? 1 : 0.45)  // bad
        Text("a ? b : c")
        Rectangle().opacity(isOn ? 1 : 0)
    }

    var inset: CGFloat { caption == nil ? 0 : 8 }  // bad
}

struct FixtureModel {
    var title: String { name ?? "" }
    var inset: CGFloat { caption == nil ? 0 : 8 }
}
