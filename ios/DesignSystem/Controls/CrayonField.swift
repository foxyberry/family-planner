import CrayonKit
import SwiftUI

/// A text field on paper, 80 tall; the marker line turns blue while focused (board C3k).
public struct CrayonField: View {
    private let placeholder: String
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .crayonType(.body)
            .focused($isFocused)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 80)
            .background(
                CrayonSurface(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                              marker: isFocused ? .standard : .thin,
                              markerColor: isFocused ? CrayonColor.link : CrayonColor.marker,
                              seed: CrayonStyle.Seed.field)
            )
    }
}
