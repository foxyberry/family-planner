import CrayonKit
import SwiftUI

/// A text field on paper, 80 tall; the marker line turns blue while focused (board C3k).
public struct CrayonField: View {
    private let placeholder: String
    private let isSecure: Bool
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    /// `isSecure` hides what is typed (keys, codes).
    public init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false) {
        self.placeholder = placeholder
        self.isSecure = isSecure
        _text = text
    }

    public var body: some View {
        field
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

    @ViewBuilder private var field: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}
