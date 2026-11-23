import SwiftUI

/// One off look for every control that cannot be pressed now (design decision, 2026-11-22): the
/// whole control at 40 %, by day and at night, and no taps. `InkButton`, `RoundButton` and
/// `CrayonSwitch` take an `isEnabled` flag from their caller's State and draw it here.
enum OffLook {
    /// The off look's opacity.
    static let opacity = 0.4
}

extension View {
    /// Draws the off look when `isEnabled` is false: the control at 40 % as one picture, disabled
    /// (UI tests read it) and taking no taps. Without `compositingGroup` each layer fades on its own,
    /// and a switch's track shows through its knob.
    public func offLook(_ isEnabled: Bool) -> some View {
        compositingGroup()
            .opacity(isEnabled ? 1 : OffLook.opacity)
            .disabled(!isEnabled)
            .allowsHitTesting(isEnabled)
    }
}

extension Button {
    /// The parts' plain button. Off, a disabled `.plain` button fades its label a second time (the
    /// off InkButton drew near 16 %), so an off button draws its label as it is and `offLook` fades it.
    @ViewBuilder func crayonPlain(_ isEnabled: Bool) -> some View {
        if isEnabled {
            buttonStyle(.plain)
        } else {
            buttonStyle(AsDrawn())
        }
    }
}

/// An off button's style: the label as drawn (it cannot be pressed, so it has no pressed look).
private struct AsDrawn: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
