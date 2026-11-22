// Fixture (not compiled): a checkout inside a folder named Tests (~/Tests/family-planner) is still
// linted; only a Tests folder under ios/ is skipped.
import SwiftUI

struct CheckoutUnderTestsView: View {
    var body: some View { Text(name ?? "") }  // bad
}
