import Strings
import SwiftUI

/// A time on paper, 80 tall; tapping opens an hour/minute wheel. `label` is the time as the
/// screen prints it ("3:30 pm", from State), so the iPad's 24-hour setting never changes it.
public struct TimeField: View {
    private let label: String
    private let isPlaceholder: Bool
    private let width: CGFloat?
    @Binding private var time: Date
    @State private var isPicking = false

    /// `isPlaceholder`: no time chosen yet; `label` is an example time in `softText` (S2).
    /// `width`: a fixed width (S2 Arrive by and latest, 180); otherwise at least 200.
    public init(label: String, time: Binding<Date>, isPlaceholder: Bool = false, width: CGFloat? = nil) {
        self.label = label
        self.isPlaceholder = isPlaceholder
        self.width = width
        _time = time
    }

    public var body: some View {
        FieldButton(label, isPlaceholder: isPlaceholder, width: width) { isPicking = true }
        .popover(isPresented: $isPicking) {
            DatePicker(L10n.tr("time.field"), selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(Spacing.m)
        }
    }
}
