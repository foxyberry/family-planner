// Fixture for `scripts/swiftlint.sh --self-test` (not compiled). The fixtures sit under the same
// paths as real code, because view_values picks its scope from the path. Every line marked `bad`
// must be reported, and no other line. This file is not a *View.swift file, so only code inside a
// type that declares `View` counts.
import SwiftUI

struct FixtureScreen: View {
    var body: some View {
        Text(store.label ?? "")  // bad
        KidNowNext(now: now ?? "actPlay")  // bad
        timeLeft(minutes: store.minutes ?? 0)  // bad
        KitIcon(KitSlot(rawValue: name) ?? .actPlay)  // bad
        Rectangle().opacity(store.canUndo ? 1 : 0.45)  // bad
        Text("a ? b : c ?? d")
        Rectangle().opacity(isOn ? 1 : 0)
        Rectangle().opacity(!store.isOn ? 1 : 0)  // bad
        Rectangle().opacity(isOn && store.canUndo ? 1 : 0)  // bad
        Rectangle().opacity((store.isOn) ? 1 : 0)  // bad
        Toggle("", isOn: $store.isOn ? a : b)  // bad
        Rectangle().opacity(restore ? 1 : 0)
        Text(store.isOn ? "store" : "nil")  // bad
        // A comment with store.label ?? "" is not code.
    }

    var inset: CGFloat { caption == nil ? -inset : 0 }  // bad
}

extension FixtureScreen: View {
    var slots: [Slot] { firstDay?.slots ?? [] }  // bad
}

struct FixtureModel {
    var title: String { name ?? "" }
    var inset: CGFloat { caption == nil ? 0 : 8 }
}
