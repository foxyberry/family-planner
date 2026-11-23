import KitArt
import SwiftUI

/// Board F7 (issue 024, layout v77): how the kid comes home from the last event of a chain. A
/// `FormCard` 640 × 480: Pickup, Bus, Walk or None as `ChoiceCircles`, then "Takes" − {n} min + (64
/// buttons, the minutes 160 wide), hidden for None. The words and choices come from the caller.
public struct BackCard: View {
    public struct Stepper: Equatable, Sendable {
        public var label: String
        public var value: String
        public var canMinus: Bool
        public var canPlus: Bool

        public init(label: String, value: String, canMinus: Bool, canPlus: Bool) {
            self.label = label
            self.value = value
            self.canMinus = canMinus
            self.canPlus = canPlus
        }
    }

    public static let size = CGSize(width: 640, height: 480)

    private let title: String
    private let choices: [ChoiceCircles.Choice]
    private let takes: Stepper?
    private let done: String
    private let cancel: String
    private let onPick: (String) -> Void
    private let onStep: (Int) -> Void
    private let onDone: () -> Void
    private let onCancel: () -> Void
    @Environment(\.sizing) private var sizing

    /// `takes` nil hides the stepper (None).
    public init(title: String, choices: [ChoiceCircles.Choice], takes: Stepper?, done: String, cancel: String,
                onPick: @escaping (String) -> Void, onStep: @escaping (Int) -> Void, onDone: @escaping () -> Void,
                onCancel: @escaping () -> Void) {
        self.title = title
        self.choices = choices
        self.takes = takes
        self.done = done
        self.cancel = cancel
        self.onPick = onPick
        self.onStep = onStep
        self.onDone = onDone
        self.onCancel = onCancel
    }

    public var body: some View {
        FormCard(title: title, size: Self.size, done: done, cancel: cancel, onDone: onDone, onCancel: onCancel) {
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                ChoiceCircles(choices, onPick: onPick)
                if let takes {
                    HStack(spacing: sizing(Spacing.m)) {
                        Text(takes.label).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                        RoundButton(glyph: .minus) { onStep(-1) }.size(64).enabled(takes.canMinus)
                        Text(takes.value).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            .frame(width: sizing(160))
                        RoundButton(glyph: .plus) { onStep(1) }.size(64).enabled(takes.canPlus)
                    }
                }
            }
        }
    }
}
