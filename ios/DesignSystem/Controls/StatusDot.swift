import CrayonKit
import SwiftUI

/// The live status after "Leave in" (spec "Header right"): head text with a 28 crayon dot, gap 16.
/// `compact` (home Kid A row, look ①): body bold with a 24 dot, gap 8.
/// On time is green, Leave now! is the hurry orange, Ask a grown-up is soft text with no dot.
/// Colour never carries the meaning alone: the words do.
public struct StatusDot: View {
    public enum Tone: Equatable, Sendable { case onTime, hurry, quiet }

    private let text: String
    private let tone: Tone
    private let compact: Bool
    @Environment(\.sizing) private var sizing

    public init(_ text: String, tone: Tone, compact: Bool = false) {
        self.text = text
        self.tone = tone
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: sizing.space(compact ? Spacing.xs : Spacing.m)) {
            if let dot {
                // The surface draws its wobble past this frame (bleed), so the frame is the dot's size.
                CrayonSurface(.circle, fill: CrayonFill(color: dot, hachure: HachureStyle(degrees: -40)),
                              marker: .thin, seed: CrayonStyle.Seed.status)
                    .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
            }
            Text(text).crayonType(compact ? .body : .head, bold: true).foregroundStyle(textColor).lineLimit(1).fixedSize()
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
