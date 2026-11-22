import CrayonKit
import SwiftUI

/// Shared crayon fills and fixed seeds, so every instance of a part looks the same.
/// Lists add their index to the seed so neighbours differ.
public enum CrayonStyle {
    /// Spec "Art inset" (2026-11-09): every part's crayon outline is drawn 6 (× s) inside its box on
    /// every side; the touch area is the whole box.
    public static let artInset: CGFloat = 6

    public static let skyPill = CrayonFill(color: CrayonColor.nowSky, hachure: HachureStyle(degrees: -30))
    public static let yellowSlider = CrayonFill(color: CrayonColor.goYellow, hachure: HachureStyle(degrees: -50))
    public static let apricot = CrayonFill(color: CrayonColor.kidApricot, hachure: HachureStyle(degrees: -35))
    public static let blueCrayon = CrayonFill(color: CrayonColor.pickBlue, hachure: HachureStyle(degrees: -40))
    public static let doneGreen = CrayonFill(color: CrayonColor.doneGreen, hachure: HachureStyle(degrees: -50))
    public static let ink = CrayonFill(color: CrayonColor.marker, hachure: nil)
    /// Chrome: white by day, night control in dark mode.
    public static let paper = CrayonFill.paper(CrayonColor.card)
    /// Picture grounds (circles and plates under pictures, the clock hub, speech bubbles): white by
    /// day, moon paper in dark mode; draw them with `CrayonColor.pictureOutline`.
    public static let pictureGround = CrayonFill.paper(CrayonColor.pictureGround)

    /// A kid's colour as crayon (S1 swatches, a face not picked yet).
    public static func kid(_ colorIndex: Int) -> CrayonFill {
        CrayonFill(color: CrayonColor.kid(colorIndex), hachure: HachureStyle(degrees: -40))
    }

    enum Seed {
        static let inkButton: UInt32 = 101
        static let roundButton: UInt32 = 301
        static let checkMark: UInt32 = 401
        static let tabs: UInt32 = 501
        static let dayChip: UInt32 = 601
        static let dateChip: UInt32 = 701
        static let field: UInt32 = 801
        static let iconPicker: UInt32 = 901
        static let slider: UInt32 = 1001
        static let card: UInt32 = 1101
        static let bubble: UInt32 = 1301
        static let league: UInt32 = 1401
        static let voice: UInt32 = 1501
        static let kidFace: UInt32 = 1601
        static let knob: UInt32 = 1701
        static let plus: UInt32 = 1801
        static let glyph: UInt32 = 1901
        static let mission: UInt32 = 2001
        static let band: UInt32 = 2101
        static let way: UInt32 = 2201
        static let status: UInt32 = 2301
        static let stepDots: UInt32 = 2401
        static let swatch: UInt32 = 2501
        static let crayonSwitch: UInt32 = 2601
        static let formCard: UInt32 = 2701
        static let dayButton: UInt32 = 2801
        static let dayPicker: UInt32 = 2901
        /// The kid card's face discs (S1 / G6f), the seed they always had.
        static let kidCardFace: UInt32 = 1650
        /// The side column's remove button (G2 "Remove every week"), the seed it always had.
        static let removeButton: UInt32 = 1903
    }
}

/// Where a part with a crayon outline takes taps (spec "Sizing → Touch", rule 1).
public enum PartTap: Equatable, Sendable {
    /// A control: only its drawn shape, the frame less the art inset (a round part its circle, a pill
    /// its capsule, a box its rounded rect).
    case drawn
    /// A container (cards, list cards, form cards): its whole frame, so a near miss just outside the
    /// outline stops on the card instead of reaching the dim behind it and cancelling the form.
    case frame
}

extension View {
    /// A part's crayon shape, drawn `CrayonStyle.artInset` × s inside the view's box (spec "Art inset").
    /// `tap`: a control takes taps only on that drawn shape (user, 2026-11-22); a container passes
    /// `.frame`.
    public func partBackground(_ kind: CrayonShapeKind, fill: CrayonFill?, seed: UInt32,
                               marker: MarkerStyle = .standard, markerColor: Color? = nil,
                               tap: PartTap = .drawn) -> some View {
        background(PartSurface(kind: kind, fill: fill, seed: seed, marker: marker, markerColor: markerColor))
            .modifier(DrawnTapShape(kind: kind, tap: tap))
    }
}

/// Spec "Sizing → Touch", rule 1: the tap area of a control with a crayon outline is its drawn shape,
/// one art inset inside its frame, × s; a container keeps its frame.
private struct DrawnTapShape: ViewModifier {
    let kind: CrayonShapeKind
    let tap: PartTap
    @Environment(\.sizing) private var sizing

    @ViewBuilder func body(content: Content) -> some View {
        let inset = sizing(CrayonStyle.artInset)
        if tap == .frame {
            content.contentShape(Rectangle())
        } else {
            drawn(content, inset: inset)
        }
    }

    @ViewBuilder private func drawn(_ content: Content, inset: CGFloat) -> some View {
        switch kind {
        case .circle: content.contentShape(Circle().inset(by: inset))
        case .capsule: content.contentShape(Capsule().inset(by: inset))
        case let .roundedRect(radius): content.contentShape(RoundedRectangle(cornerRadius: sizing(radius)).inset(by: inset))
        case .speechBubble, .sector, .hill: content.contentShape(Rectangle().inset(by: inset))
        }
    }
}

/// A crayon surface one art inset inside its box, at this screen's scale.
private struct PartSurface: View {
    let kind: CrayonShapeKind
    let fill: CrayonFill?
    let seed: UInt32
    let marker: MarkerStyle
    let markerColor: Color?
    @Environment(\.sizing) private var sizing

    var body: some View {
        CrayonSurface(kind, fill: fill, marker: marker, markerColor: markerColor, seed: seed)
            .padding(sizing(CrayonStyle.artInset))
    }
}
