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
    /// Over an hour: "1 h 20 min" (or "2 h") in the same size.
    nonisolated public static func presentation(minutes: Int) -> Presentation {
        let tone: Tone = minutes > 0 ? .normal : .late
        if minutes > 60 {
            let hours = minutes / 60, rest = minutes % 60
            let text = rest == 0 ? L10n.tr("time_left.h", "\(hours)") : L10n.tr("time_left.h_min", "\(hours)", "\(rest)")
            return Presentation(text: text, tone: tone)
        }
        let number = minutes < 0 ? "\u{2212}\(-minutes)" : "\(minutes)"
        return Presentation(text: L10n.tr("time_left.min", number), tone: tone)
    }

    /// What VoiceOver says (spec "Spoken times"): full words, "38 minutes", "1 hour 20 minutes",
    /// "1 minute"; at zero or below, "2 minutes late".
    nonisolated public static func spoken(minutes: Int) -> String {
        let total = abs(minutes)
        let hours = total / 60, rest = total % 60
        let minutePart = rest == 1 ? L10n.tr("time_left.spoken.min_one") : L10n.tr("time_left.spoken.min", rest)
        let hourPart = hours == 1 ? L10n.tr("time_left.spoken.h_one") : L10n.tr("time_left.spoken.h", hours)
        let words = hours == 0 ? minutePart : rest == 0 ? hourPart : L10n.tr("time_left.spoken.h_min", hourPart, minutePart)
        return minutes < 0 ? L10n.tr("time_left.spoken.late", words) : words
    }

    private let minutes: Int
    private let look: KidLook
    private let compact: Bool
    @Environment(\.sizing) private var sizing

    /// `compact`: 72 bold beside a picture (home Kid A row, look ①, layout v17) instead of the
    /// display 96; "1h 20m" then fits the 272 beside the 96 picture.
    public init(minutes: Int, look: KidLook = .day, compact: Bool = false) {
        self.minutes = minutes
        self.look = look
        self.compact = compact
    }

    public var body: some View {
        let p = Self.presentation(minutes: minutes)
        // 72 is three quarters of display 96, and shrinks with it on smaller screens.
        let size = sizing.size(of: .display) * (compact ? 0.75 : 1)
        Text(p.text)
            .font(Font(FontRegistrar.font(size: size, weight: .bold)))
            .foregroundStyle(p.tone == .late ? CrayonColor.lateText : look.ink)
            .monospacedDigit()
            .lineLimit(1)
            // Line height 1.0: the box is as tall as the type (96 or 72 on the board), not the
            // font's taller default.
            .frame(height: size * CrayonType.display.lineHeight)
            .accessibilityLabel(Self.spoken(minutes: minutes))
    }
}
