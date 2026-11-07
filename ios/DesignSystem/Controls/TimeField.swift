import CrayonKit
import SwiftUI

/// A time on paper, 80 tall; tapping opens an hour/minute wheel.
public struct TimeField: View {
    @Binding private var time: Date
    @State private var isPicking = false

    public init(time: Binding<Date>) {
        _time = time
    }

    public var body: some View {
        Button { isPicking = true } label: {
            Text(time, format: .dateTime.hour().minute())
                .crayonType(.body)
                .foregroundStyle(CrayonColor.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minWidth: 200, minHeight: 80)
                .crayonBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.field + 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPicking) {
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(Spacing.m)
        }
    }
}
