import CrayonKit
import SwiftUI

/// The live status after "Leave in" (spec "Header right"): head text with a 28 crayon dot, gap 16.
/// On time is green, Leave now! is the hurry orange, Ask a grown-up is soft text with no dot.
/// Colour never carries the meaning alone: the words do.
public struct StatusDot: View {
    public enum Tone: Equatable, Sendable { case onTime, hurry, quiet }

    private let text: String
    private let tone: Tone
    @Environment(\.sizing) private var sizing

    public init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: sizing.space(Spacing.s)) {
            if let dot {
                CrayonSurface(.circle, fill: CrayonFill(color: dot, hachure: HachureStyle(degrees: -40)),
                              marker: .thin, seed: CrayonStyle.Seed.status)
                    .frame(width: 34, height: 34) // 28 drawn, plus the marker wobble
            }
            Text(text).crayonType(.head).foregroundStyle(textColor).lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private var dot: Color? {
        switch tone {
        case .onTime: CrayonColor.onTimeGreen
        case .hurry: CrayonColor.hurry
        case .quiet: nil
        }
    }

    private var textColor: Color {
        switch tone {
        case .onTime: CrayonColor.onTimeText
        case .hurry: CrayonColor.ink
        case .quiet: CrayonColor.softText
        }
    }
}
