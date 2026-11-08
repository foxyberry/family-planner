import SwiftUI

/// The six text sizes of the crayon type scale. Nothing on screen is smaller than caption (24).
public enum CrayonType: CaseIterable, Sendable {
    case hero, display, title, head, body, caption

    public var size: CGFloat {
        switch self {
        case .hero: 144
        case .display: 96
        case .title: 48
        case .head: 36
        case .body: 30
        case .caption: 24
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .hero, .display, .title, .head: .bold
        case .body, .caption: .medium
        }
    }

    /// Line height as a multiple of the size.
    public var lineHeight: CGFloat {
        switch self {
        case .hero, .display: 1.0
        case .title: 1.15
        case .head: 1.2
        case .body: 1.25
        case .caption: 1.3
        }
    }

    /// Playpen Sans at this size and weight.
    var font: Font {
        Font(FontRegistrar.font(size: size, weight: weight == .bold ? .bold : .medium))
    }
}

extension View {
    /// Applies a crayon text style: font, size, weight and line spacing.
    public func crayonType(_ type: CrayonType) -> some View {
        font(type.font)
            .lineSpacing(type.size * (type.lineHeight - 1))
    }

    /// A crayon text style in bold, for the few places a body or caption is bold (way strip labels).
    public func crayonType(_ type: CrayonType, bold: Bool) -> some View {
        font(Font(FontRegistrar.font(size: type.size, weight: bold ? .bold : .medium)))
            .lineSpacing(type.size * (type.lineHeight - 1))
    }
}
