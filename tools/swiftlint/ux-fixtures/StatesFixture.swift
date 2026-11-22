// Fixture for `scripts/ux-states.sh --self-test` (not compiled); its expected inventory is
// tools/swiftlint/ux-fixtures/expected.txt.

/// The kid's block.
/// ux-states: fixture home
enum FixtureBlock {
    /// A1 / A1m / E1: leave.
    case leave
    /// A1n: bed time.
    case bedTime(Int)
    /// Nothing next today: the row is left out (spec E3 "No item left today").
    case nothing
    case bare, twin
    /// E9: a board that doesn't exist.
    case missing
}

/// Not part of the inventory: no ux-states line.
enum FixtureOther {
    /// A1: ignored.
    case ignored
}
