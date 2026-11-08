import CrayonKit
import Strings
import SwiftUI

/// A time on paper, 80 tall; tapping opens an hour/minute wheel. `label` is the time as the
/// screen prints it ("3:30 pm", from State), so the iPad's 24-hour setting never changes it.
public struct TimeField: View {
    private let label: String
    @Binding private var time: Date
    @State private var isPicking = false

    public init(label: String, time: Binding<Date>) {
        self.label = label
        _time = time
    }

    public var body: some View {
        Button { isPicking = true } label: {
            Text(label)
                .crayonType(.body)
                .foregroundStyle(CrayonColor.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minWidth: 200, minHeight: 80)
                .crayonBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.field + 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPicking) {
            DatePicker(L10n.tr("time.field"), selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(Spacing.m)
        }
    }
}
