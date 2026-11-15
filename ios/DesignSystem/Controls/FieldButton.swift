import CrayonKit
import SwiftUI

/// A value on paper, 80 tall, that opens a picker or a card when tapped: the look of `TimeField`
/// and `DateField`, and of a field like Runs' end ("End of term", spec "Repeats, dates and changes").
public struct FieldButton: View {
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
                // A narrow field on a smaller iPad shrinks its time a little rather than cut it.
                .minimumScaleFactor(0.75)
                .padding(.horizontal, Spacing.m)
                .frame(minWidth: width ?? 200, maxWidth: width, minHeight: 80)
                .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.field + 1,
                                markerColor: isActive ? CrayonColor.pickBlue : hasProblem ? CrayonColor.lateText : CrayonColor.outline)
        }
        .buttonStyle(.plain)
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
