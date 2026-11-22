// Fixture (not compiled): a *View.swift file is view code throughout, so helpers outside a `View`
// type count too.
import SwiftUI

struct FixtureRowView: View {
    var body: some View { Text(title) }
}

extension FixtureRowView {
    var title: String { name ?? "" }  // bad
}

struct FixtureRowStyle {
    var inset: CGFloat { caption == nil ? 0 : 8 }  // bad
    var width: CGFloat { isWide ? 2 : 1 }
}

private func rowHeight(_ store: Row) -> CGFloat { store.isTall ? 80 : 60 }  // bad
