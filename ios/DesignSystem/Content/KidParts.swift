import CrayonKit
import KitArt
import SwiftUI

/// A kid's progress ring (board 0c2, spec "CrayonKit UI parts"): a beige track and an arc in the
/// kid's colour from 12 o'clock clockwise, 0…1. The kid chips use 76.
public struct CrayonRing: View {
    private let progress: Double
    private let colorIndex: Int
    private let size: CGFloat

    public init(progress: Double, colorIndex: Int, size: CGFloat = 76) {
        self.progress = min(max(progress, 0), 1)
        self.colorIndex = colorIndex
        self.size = size
    }

    public var body: some View {
        let colour = CrayonColor.kid(colorIndex)
        let inset = size * 0.07
        ZStack {
            Circle().stroke(CrayonPalette.ringTrack.color, lineWidth: size * 0.08)
            Circle().trim(from: 0, to: progress)
                .stroke(colour.opacity(0.35), style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().trim(from: 0, to: progress)
                .stroke(colour, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(inset)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The chosen kid's band in the kid list (board 0c2): a rounded band in the kid's light tint with a
/// 14 pt notch pointing at the missions it controls, and a soft edge line. 340 × 100 in A2.
public struct KidBand: View {
    private let colorIndex: Int

    public init(colorIndex: Int) {
        self.colorIndex = colorIndex
    }

    public var body: some View {
        let (tint, edge) = colorIndex == 1
            ? (CrayonPalette.kidBTint.color, CrayonPalette.kidBTintEdge.color)
            : (CrayonPalette.kidATint.color, CrayonPalette.kidATintEdge.color)
        ZStack {
            BandShape().fill(tint)
            BandShape().stroke(edge, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }

    /// A rounded band (r 28) with a 14 pt notch on its trailing side, as one outline.
    private struct BandShape: Shape {
        func path(in rect: CGRect) -> Path {
            let notch: CGFloat = 14, radius: CGFloat = 28
            let right = rect.maxX - notch
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: right, y: rect.minY), tangent2End: CGPoint(x: right, y: rect.maxY),
                        radius: radius)
            path.addLine(to: CGPoint(x: right, y: rect.midY - notch))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: right, y: rect.midY + notch))
            path.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
                        radius: radius)
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY),
                        radius: radius)
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: right, y: rect.minY),
                        radius: radius)
            path.closeSubpath()
            return path
        }
    }
}

/// One mission (board 0c2, backlog N2): a 112 crayon circle in the kid's fill (Kid A sky, Kid B
/// apricot) with the mission's picture, its name under it (bold for the one to do now), and a blue
/// check badge when done.
public struct MissionCircle: View {
    /// What sits inside the kid's crayon circle.
    public enum Content: Equatable, Sendable {
        /// A mission picture.
        case picture(KitSlot)
        /// "+3": more missions on the next page (title 48 bold).
        case text(String)
        /// The done missions folded into one: a large tick.
        case tick
        /// A marker glyph, such as "‹" to turn back a page.
        case glyph(MarkerGlyph)
    }

    private let content: Content
    private let name: String
    private let colorIndex: Int
    private let isDone: Bool
    private let isCurrent: Bool

    public static let size: CGFloat = 112
    @Environment(\.sizing) private var sizing

    public init(picture: KitSlot, name: String, colorIndex: Int, isDone: Bool, isCurrent: Bool) {
        self.init(.picture(picture), name: name, colorIndex: colorIndex, isDone: isDone, isCurrent: isCurrent)
    }

    /// `name` is the caption under the circle ("Teeth", "3 more", "3 done").
    public init(_ content: Content, name: String, colorIndex: Int, isDone: Bool = false, isCurrent: Bool = false) {
        self.content = content
        self.name = name
        self.colorIndex = colorIndex
        self.isDone = isDone
        self.isCurrent = isCurrent
    }

    /// 112 × s, never under the 64 kid tap target.
    private var circle: CGFloat { max(64, Self.size * sizing.s) }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                CrayonSurface(.circle, fill: colorIndex == 1 ? CrayonStyle.apricot : CrayonStyle.skyPill,
                              seed: CrayonStyle.Seed.mission + UInt32(max(0, colorIndex)))
                inside
            }
            .frame(width: circle, height: circle)
            .overlay(alignment: .topTrailing) {
                if isDone { CheckMark(isDone: true, size: 40).offset(x: Spacing.xxs, y: -Spacing.xxs) }
            }
            Text(name)
                .font(Font(FontRegistrar.font(size: CrayonType.caption.size, weight: isCurrent ? .bold : .medium)))
                .foregroundStyle(CrayonColor.ink)
                // Never under the 24 floor (spec "Sizing formulas"): a long name wraps instead.
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: circle + Spacing.m)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var inside: some View {
        switch content {
        case let .picture(picture): KitIcon(picture, size: circle * 0.64)
        case let .text(text): Text(verbatim: text).crayonType(.title).foregroundStyle(CrayonColor.ink)
        case .tick: CheckMark(isDone: true, size: circle * 0.56)
        case let .glyph(glyph): MarkerIcon(glyph, size: circle * 0.4)
        }
    }
}
