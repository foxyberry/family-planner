import Strings
import SwiftUI

/// Minutes left, big: ink while there is time, late red at zero or below ("−2 min").
public struct TimeLeft: View {
    public enum Tone: Equatable, Sendable { case normal, late }

    public struct Presentation: Equatable, Sendable {
        public let text: String
        public let tone: Tone
    }

    /// The label and tone for `minutes`. Negative values use the true minus sign (U+2212).
    nonisolated public static func presentation(minutes: Int) -> Presentation {
        let number = minutes < 0 ? "\u{2212}\(-minutes)" : "\(minutes)"
        return Presentation(text: L10n.tr("time_left.min", number), tone: minutes > 0 ? .normal : .late)
    }

    private let minutes: Int

    public init(minutes: Int) {
        self.minutes = minutes
    }

    public var body: some View {
        let p = Self.presentation(minutes: minutes)
        Text(p.text)
            .crayonType(.display)
            .foregroundStyle(p.tone == .late ? CrayonColor.lateText : CrayonColor.ink)
            .monospacedDigit()
    }
}
