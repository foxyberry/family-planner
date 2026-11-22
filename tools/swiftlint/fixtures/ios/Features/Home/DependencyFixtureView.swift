// Fixture for outside_data (not compiled): in a *View.swift file every @Dependency is a view's, even
// outside a `View` type.
import SwiftUI

struct DependencyFixtureView: View {
    var body: some View { Text("Row") }
}

struct DependencyFixtureHelper {
    @Dependency(\.calendar) private var calendar  // bad
}
