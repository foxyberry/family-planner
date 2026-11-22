// Fixture for layout_literals (not compiled): a screen file (*View.swift under ios/Features). Every
// line marked `bad` must be reported, and no other line.
import SwiftUI

struct LayoutFixtureView: View {
    var body: some View {
        VStack(spacing: 12) {  // bad
            Text("a")
                .offset(x: 20, y: -20)  // bad
            Text("b")
                .frame(width: 112)  // bad
                .padding(.leading, layout.inset + 8)  // bad
                .padding(0.5)  // bad
            SetupRow(label: day, height: 72) {}  // bad
            ListRow(leading: x, minHeight: 80, labelHeight: 80) {}  // bad
            CrayonTabs(itemSize: CGSize(width: tabWidth, height: 72))  // bad
            SetupRow(label: day, height: sizing.tabHeight()) {}
            ListRow(leading: x, minHeight: 0) {}
            Text("c")
                .frame(width: sizing.swatch2, height: layout.row)
                .padding(.top, Spacing.m)
                .frame(width: 0)
            HStack(spacing: Spacing.sm) {
                Text("d").opacity(0.5)
                Text("e").lineLimit(2)
            }
            Text("12 apples, .frame(width: 3)")
            PaperCard(seed: 52) { Text("f") }.frame(maxWidth: .infinity)
            MarkerIcon(.plus, size: sizing(28)).frame(width: layout.icon)
            PaperCard(seed: 61) { Text("g") }.padding(4)  // bad
        }
    }
}
