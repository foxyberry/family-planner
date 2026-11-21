import CrayonKit
import SwiftUI

/// A value on paper, 80 tall, that opens a picker or a card when tapped: the look of `TimeField`
/// and `DateField`, and of a field like Runs' end ("End of term", spec "Repeats, dates and changes").
public struct FieldButton: View {
    @Environment(\.sizing) private var sizing
    private let label: String
    private let isPlaceholder: Bool
    private let width: CGFloat?
    private let isActive: Bool
    private let action: () -> Void
    @Environment(\.fieldHasProblem) private var hasProblem

    /// `isPlaceholder`: an example value in `softText`. `width`: fixed; otherwise at least 200.
    /// `isActive`: the value is being changed (its picker is open); the outline turns `pickBlue`
    /// (layout v43, "the field being changed is pickBlue").
    public init(_ label: String, isPlaceholder: Bool = false, width: CGFloat? = nil, isActive: Bool = false,
                action: @escaping () -> Void) {
        self.label = label
        self.isPlaceholder = isPlaceholder
        self.width = width
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .crayonType(.body)
                .foregroundStyle(isPlaceholder ? CrayonColor.softText : CrayonColor.ink)
                .lineLimit(1)
                // Spec "Part floors": text never shrinks. With a formula width (TimeField) the text is
                // centred and adds no padding (it keeps 16 clear); without one the field is 200 × s
                // (200 on the 13"), never narrower than its text + fluid(24, 16) on each side.
                .padding(.horizontal, width == nil ? sizing.textPadding : 0)
                .frame(minWidth: minWidth, maxWidth: width, minHeight: sizing.fieldHeight)
                .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.field + 1,
                                markerColor: isActive ? CrayonColor.pickBlue : hasProblem ? CrayonColor.lateText : CrayonColor.outline)
        }
        .buttonStyle(.plain)
    }

    /// The fixed `width`, else 200 × s.
    private var minWidth: CGFloat {
        if let width { width } else { 200 * sizing.s }
    }
}

/// A date on paper (Runs' start, spec "Repeats, dates and changes"); tapping opens a month view.
/// `label` is the date as the screen prints it ("9 Nov", from State).
public struct DateField: View {
    private let label: String
    private let width: CGFloat?
    @Binding private var date: Date
    @State private var isPicking = false

    public init(label: String, date: Binding<Date>, width: CGFloat? = nil) {
        self.label = label
        self.width = width
        _date = date
    }

    public var body: some View {
        FieldButton(label, width: width, isActive: isPicking) { isPicking = true }
            .popover(isPresented: $isPicking) {
                DatePicker(label, selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(width: 360)
                    .padding(Spacing.m)
            }
    }
}
