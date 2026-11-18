import CrayonKit
import SwiftUI

/// Spec "Layout model" → `FormLayout` and "Layout balance": the lines of one form card on one
/// `Sizing`, as pure geometry so tests check the relations without drawing. Every x is measured from
/// the card's label line (board x 78); `width` runs from there to the right-edge line (board 808).
///
/// - Labels sit on the label line; controls start on the control line, one fixed label column (114)
///   past it on every grown-up form (spec "Label column": a longer label is reworded).
/// - A second column ("Age", "Face" on S1) has one label line and one control line per card: its
///   controls end on the right edge, its label line is its control line − (longest second-column
///   label + 10), and it drops under the first column when the column gap (the first column's
///   drawn end → the second label) would fall under 40.
/// - Gaps are measured between drawn edges (frame − `CrayonPart.inset`); these lines are frames.
public struct FormLines: Equatable, Sendable {
    public struct SecondColumn: Equatable, Sendable {
        /// The second label line, from the card's label line (0 when the column drops under the
        /// first).
        public let labelX: CGFloat
        /// The column's frame: its controls' frames, or `partInset()` around a part drawn to its edge.
        public let controlX: CGFloat
        public let controlWidth: CGFloat
        /// True when it does not fit beside the first column and sits under it instead.
        public let dropsUnder: Bool
    }

    /// Spec "Label column": the longest grown-up label ("Off days", caption 24 bold, 104) + 10 to the
    /// control's frame (16 to its drawn box). Captions are fixed at 24, so it does not scale.
    public static let labelColumn: CGFloat = 114
    /// The widest label that fits the column; a longer one is reworded.
    public static let labelMaximum: CGFloat = 104
    /// Spec "Layout balance": the column gap, drawn edge to drawn edge, fixed.
    public static let columnGap: CGFloat = Spacing.l
    /// A second-column label's room past its longest label, to its control's frame (16 drawn).
    public static let secondLabelGap: CGFloat = labelColumn - labelMaximum

    /// From the label line to the right-edge line.
    public let width: CGFloat
    /// The control line, measured from the label line (the label column's width).
    public let controlX: CGFloat
    public let second: SecondColumn?

    /// - Parameters:
    ///   - width: label line to right-edge line (`GrownupLayout.formRowsWidth`).
    ///   - secondLabels: the second column's labels; empty for one column.
    ///   - secondControlWidth: the second column's widest control, drawn, from its parts (S1: two
    ///     faces). The column's frame is one inset wider each side, so it ends drawn on the right
    ///     edge's drawn line (802 on the 13", spec "Alignment contract").
    ///   - firstControlMinimum: the narrowest the first column's controls may be, as frames from the
    ///     control line, for the drop rule (S1: four swatches).
    public init(width: CGFloat, secondLabels: [String] = [], secondControlWidth: CGFloat = 0,
                firstControlMinimum: CGFloat = 0) {
        self.width = width
        controlX = Self.labelColumn
        guard !secondLabels.isEmpty else {
            second = nil
            return
        }
        let labelWidth = (secondLabels.map { CrayonType.captionBoldWidth($0) }.max() ?? 0) + Self.secondLabelGap
        let frameWidth = secondControlWidth + 2 * CrayonPart.inset
        let besideControlX = width - frameWidth
        let besideLabelX = besideControlX - labelWidth
        let firstDrawnEnd = controlX + firstControlMinimum - CrayonPart.inset
        let drops = besideLabelX - firstDrawnEnd < Self.columnGap
        second = drops
            ? SecondColumn(labelX: 0, controlX: controlX, controlWidth: frameWidth, dropsUnder: true)
            : SecondColumn(labelX: besideLabelX, controlX: besideControlX, controlWidth: frameWidth,
                           dropsUnder: false)
    }

    /// The first column's control width: to the right edge, or to its drawn end 40 before a second
    /// column that stands beside it.
    public var firstControlWidth: CGFloat {
        guard let second, !second.dropsUnder else { return width - controlX }
        return second.labelX - Self.columnGap + CrayonPart.inset - controlX
    }

    /// Spec "Layout balance": the main form card's padding, 32 from its drawn edge on all four sides.
    /// `FormRow` lays out its drawn box, so top and bottom are 32 + the card's inset; the left reaches
    /// the label line (text has no inset); the right reaches the right-edge line (a control's frame).
    public static let cardPadding = EdgeInsets(top: Spacing.card + CrayonPart.inset,
                                               leading: Spacing.card + CrayonPart.inset,
                                               bottom: Spacing.card + CrayonPart.inset,
                                               trailing: Spacing.card)
    /// Card → card 40 between drawn edges, fixed: frames sit 28 apart.
    public static let cardGap: CGFloat = Spacing.l - 2 * CrayonPart.inset
}

public extension GrownupLayout {
    /// A form card's rows run from the label line (card + 38, board 78) to the right-edge line
    /// (card right − 32, board 808).
    var formRowsWidth: CGFloat { editorRowsWidth }

    func formLines(secondLabels: [String] = [], secondControlWidth: CGFloat = 0,
                   firstControlMinimum: CGFloat = 0) -> FormLines {
        FormLines(width: formRowsWidth, secondLabels: secondLabels, secondControlWidth: secondControlWidth,
                  firstControlMinimum: firstControlMinimum)
    }
}

public extension Sizing {
    /// Spec "Layout balance": row → row 24 between drawn edges (`fluid(24, 16)`).
    var formRowGap: CGFloat { space(Spacing.m) }
    /// Spec "Layout model" row heights, as frames: a field row 80 (the field's height); a picture
    /// choice row (faces in `partInset()`, swatches) as tall as its tallest frame. Rows grow with
    /// their content.
    var fieldRowHeight: CGFloat { fieldHeight }
    var choiceRowHeight: CGFloat { max(pickedFace + 2 * CrayonPart.inset, ColourSwatch.frame(self)) }
    /// A picked face's ring (an overlay; it never moves layout).
    var pickedFaceRing: CGFloat { pickedFace + 2 * CrayonPart.pickRing }
}

/// The alignment contract's shared numbers (spec "Layout model").
public enum CrayonPart {
    /// Every part draws its crayon outline this far inside its frame.
    public static let inset: CGFloat = 6
    /// The ring's overlay width: a pick ring draws this far outside the part, as an overlay. It
    /// never moves layout.
    public static let pickRing: CGFloat = 4
}

public extension EdgeInsets {
    /// The same padding on every side.
    init(all value: CGFloat) { self.init(top: value, leading: value, bottom: value, trailing: value) }
}

public extension View {
    /// Spec "Layout balance": a row of crayon parts (fields, tabs, pills, chips, time fields) lays out
    /// its drawn box, one inset inside its frames top and bottom, so a card's rows sit
    /// `formRowGap` apart and `FormLines.cardPadding` from its edge, between drawn edges.
    func drawnRow() -> some View { padding(.vertical, -CrayonPart.inset) }

    /// Spec "Alignment contract": a part drawn to its frame edge (faces, chevrons, switches,
    /// borderless rows) gets one crayon inset around it, so its frame sits on the lines and its
    /// drawn edge lines up with every crayon part's (802, not 808, on the 13").
    func partInset() -> some View { padding(CrayonPart.inset) }
}

public extension EnvironmentValues {
    /// The current form card's lines (`FormRow` reads them); set with `.formLines(_:)`.
    @Entry var formLines: FormLines? = nil
}

public extension View {
    /// Puts a form card's rows on `lines`.
    func formLines(_ lines: FormLines) -> some View {
        environment(\.formLines, lines)
            .environment(\.formLabelWidth, lines.controlX)
    }
}

/// The kind of control a row holds; rows of one kind share one height. A row lays out its drawn box
/// (its frame less the kind's inset), so the gaps around it are drawn-edge gaps (spec "Layout
/// balance").
public enum FormRowKind: Sendable {
    /// Crayon fields: frame 80, drawn one inset inside.
    case field
    /// Picture choices: faces (drawn to their edge, so placed in `partInset()`) and swatches; the
    /// drawn box is the tallest drawn part.
    case choice

    func minHeight(_ sizing: Sizing) -> CGFloat {
        switch self {
        case .field: sizing.fieldRowHeight
        case .choice: sizing.choiceRowHeight
        }
    }

    func drawnInset(_ sizing: Sizing) -> CGFloat {
        switch self {
        case .field: CrayonPart.inset
        case .choice: (sizing.choiceRowHeight - max(sizing.pickedFace, sizing.swatch)) / 2
        }
    }
}

/// One row of a form card: the label centred on its control, the control on the control line, and
/// an optional second column on the card's second lines, or under the row when the card drops it.
public struct FormRow<Control: View, Second: View>: View {
    private let label: String
    private let secondLabel: String?
    private let kind: FormRowKind
    private let control: Control
    private let secondControl: Second
    @Environment(\.formLines) private var lines
    @Environment(\.sizing) private var sizing

    public init(_ label: String, kind: FormRowKind, @ViewBuilder control: () -> Control) where Second == EmptyView {
        self.label = label
        secondLabel = nil
        self.kind = kind
        self.control = control()
        secondControl = EmptyView()
    }

    public init(_ label: String, kind: FormRowKind, second secondLabel: String,
                @ViewBuilder control: () -> Control, @ViewBuilder secondControl: () -> Second) {
        self.label = label
        self.secondLabel = secondLabel
        self.kind = kind
        self.control = control()
        self.secondControl = secondControl()
    }

    public var body: some View {
        if let lines {
            if let secondLabel, let second = lines.second {
                if second.dropsUnder {
                    VStack(alignment: .leading, spacing: sizing.formRowGap) {
                        cell(label, labelWidth: lines.controlX, width: lines.width - lines.controlX) { control }
                        cell(secondLabel, labelWidth: lines.controlX, width: second.controlWidth) { secondControl }
                    }
                } else {
                    HStack(alignment: .center, spacing: FormLines.columnGap) {
                        cell(label, labelWidth: lines.controlX, width: lines.firstControlWidth) { control }
                        cell(secondLabel, labelWidth: second.controlX - second.labelX,
                             width: second.controlWidth) { secondControl }
                    }
                }
            } else {
                cell(label, labelWidth: lines.controlX, width: lines.width - lines.controlX) { control }
            }
        }
    }

    /// A label in its column, centred on its control's box, then the control.
    private func cell<C: View>(_ text: String, labelWidth: CGFloat, width: CGFloat,
                               @ViewBuilder control: () -> C) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(text).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            control().frame(width: width, alignment: .leading)
        }
        .frame(minHeight: kind.minHeight(sizing))
        .padding(.vertical, -kind.drawnInset(sizing))
    }
}

public extension View {
    /// Spec S1 "Remove a kid" (board v54): a control centred on a card's drawn top-right corner
    /// (one inset in from the frame's right and top), so it never reaches into the next region;
    /// `popover` hangs under it, right-aligned. Placement lives here so screens carry no offsets.
    func cardCorner<Corner: View, Popover: View>(size: CGFloat, @ViewBuilder _ corner: () -> Corner,
                                                 @ViewBuilder popover: () -> Popover) -> some View {
        let corner = corner()
        let popover = popover()
        return overlay(alignment: .topTrailing) {
            corner
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    popover.alignmentGuide(.top) { $0[.top] - size }
                }
                .alignmentGuide(.trailing) { $0[.trailing] - size / 2 + CrayonPart.inset }
                .alignmentGuide(.top) { $0[.top] + size / 2 - CrayonPart.inset }
        }
    }
}

public extension EdgeInsets {
    /// How far `cardCorner(size:)` and its touch area reach past the card's top and right edges,
    /// plus one inset for crayon wobble, for a scroll column's `bleed`: a scroll view neither draws
    /// nor takes touches outside its frame.
    static func cardCorner(touch: CGFloat) -> EdgeInsets {
        EdgeInsets(top: touch / 2, leading: 0, bottom: 0, trailing: touch / 2)
    }
}
