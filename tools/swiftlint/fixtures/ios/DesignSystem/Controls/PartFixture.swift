// Fixture (not compiled): a DesignSystem part folder is view code throughout for `??`, but a part
// may branch on its own options, so its ternaries are fine.
import SwiftUI

struct FixturePart: View {
    var body: some View {
        Rectangle().opacity(store.isOn ? 1 : 0)
        Rectangle().frame(height: caption == nil ? 40 : 56)
        Text(label ?? "")  // bad
    }
}

struct FixturePartStyle {
    var inset: CGFloat { custom ?? 8 }  // bad
}
