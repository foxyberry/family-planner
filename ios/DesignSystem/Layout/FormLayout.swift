import CrayonKit
import SwiftUI

/// Spec "Layout model" → `FormLayout`: the lines of one form card on one `Sizing`, as pure geometry
/// so tests check the relations without drawing. Every x is measured from the card's label line
/// (board x 80); `width` runs from there to the right-edge line (board 818).
///
/// - Labels sit on the label line; controls start on the control line (board 208, wider for a long
///   label: spec "Label column").
/// - A second column ("Age", "Face" on S1) has one label line and one control line per card: its
///   controls end on the right edge, its label line is its control line − (longest second-column
///   label + 16), and it drops under the first column when the first column's controls would come
///   within 24 of it.
public struct FormLines: Equatable, Sendable {
    public struct SecondColumn: Equatable, Sendable {
        /// The second label line, from the card's label line (equal to `controlX`'s label line, 0,
        /// when the column drops under the first).
        public let labelX: CGFloat
        public let controlX: CGFloat
        public let controlWidth: CGFloat
        /// True when it does not fit beside the first column and sits under it instead.
        public let dropsUnder: Bool
    }

    /// Between labels and their controls, and between a first column's controls and a second
    /// column's label (spec: "within 24").
    public static let columnGap: CGFloat = Spacing.m
    /// A second-column label's room past its longest label.
    public static let secondLabelGap: CGFloat = Spacing.s

    /// From the label line to the right-edge line.
    public let width: CGFloat
    /// The control line, measured from the label line (the label column's width).
    public let controlX: CGFloat
    public let second: SecondColumn?

    /// - Parameters:
    ///   - width: label line to right-edge line (`GrownupLayout.formRowsWidth`).
    ///   - labels: the first column's labels.
    ///   - secondLabels: the second column's labels; empty for one column.
    ///   - secondControlWidth: the second column's widest control, from its parts (S1: two faces).
    ///   - firstControlMinimum: the narrowest the first column's controls may be, from its parts,
    ///     for the drop rule (S1: four swatches).
    public init(sizing: Sizing, width: CGFloat, labels: [String], secondLabels: [String] = [],
                secondControlWidth: CGFloat = 0, firstControlMinimum: CGFloat = 0) {
        self.width = width
        controlX = sizing.labelColumn(base: 128 * sizing.s, labels: labels)
        guard !secondLabels.isEmpty else {
            second = nil
            return
        }
        let labelWidth = (secondLabels.map { CrayonType.captionBoldWidth($0) }.max() ?? 0) + Self.secondLabelGap
        let besideControlX = width - secondControlWidth
        let besideLabelX = besideControlX - labelWidth
        let drops = controlX + firstControlMinimum + Self.columnGap > besideLabelX
        second = drops
            ? SecondColumn(labelX: 0, controlX: controlX, controlWidth: secondControlWidth, dropsUnder: true)
            : SecondColumn(labelX: besideLabelX, controlX: besideControlX, controlWidth: secondControlWidth,
                           dropsUnder: false)
    }

    /// The first column's control width: to the right edge, or to 24 before a second column that
    /// stands beside it.
    public var firstControlWidth: CGFloat {
        guard let second, !second.dropsUnder else { return width - controlX }
        return second.labelX - Self.columnGap - controlX
    }
}

public extension GrownupLayout {
    /// A form card's rows run from the label line (80) to the right-edge line (818).
    var formRowsWidth: CGFloat { editorRowsWidth }

    func formLines(labels: [String], secondLabels: [String] = [], secondControlWidth: CGFloat = 0,
                   firstControlMinimum: CGFloat = 0) -> FormLines {
        FormLines(sizing: sizing, width: formRowsWidth, labels: labels, secondLabels: secondLabels,
                  secondControlWidth: secondControlWidth, firstControlMinimum: firstControlMinimum)
    }
}

public extension Sizing {
    /// Spec "Layout model" row heights: a field row 80 (the field's height), a choice row 72 (a
    /// picked face with its ring). Rows grow with their content; these are minimums.
    var fieldRowHeight: CGFloat { fieldHeight }
    var choiceRowHeight: CGFloat { pickedFace + 2 * CrayonPart.pickRing }
}

/// The alignment contract's shared numbers (spec "Layout model").
public enum CrayonPart {
    /// Every part draws its crayon outline this far inside its frame.
    public static let inset: CGFloat = 6
    /// The ring's overlay width: a pick ring draws this far outside the part, as an overlay. It
    /// never moves layout; only a row's minimum height (`choiceRowHeight`) leaves room for it.
    public static let pickRing: CGFloat = 4
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

/// The kind of control a row holds; rows of one kind share one height.
public enum FormRowKind: Sendable {
    case field, choice

    func minHeight(_ sizing: Sizing) -> CGFloat {
        switch self {
        case .field: sizing.fieldRowHeight
        case .choice: sizing.choiceRowHeight
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
                    VStack(alignment: .leading, spacing: Spacing.s) {
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
    }
}

public extension View {
    /// Spec S1 "Remove a kid" (board v51): a control on a card's top-right corner, its centre one
    /// inset outside the card's right edge and two insets below its top; `popover` hangs under it,
    /// right-aligned. Placement lives here so screens carry no offsets.
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
                .alignmentGuide(.trailing) { $0[.trailing] - size / 2 - CrayonPart.inset }
                .alignmentGuide(.top) { $0[.top] + size / 2 - 2 * CrayonPart.inset }
        }
    }
}
