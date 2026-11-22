// Fixture for layout_literals (not compiled): layouts hold the numbers; only *View.swift screens are
// checked.
import SwiftUI

struct HomeLayoutFixture {
    let row = CGSize(width: 112, height: 72)
    func place(_ view: some View) -> some View { view.frame(width: 112).padding(8) }
}
