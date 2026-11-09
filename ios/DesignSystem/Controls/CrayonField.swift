import CrayonKit
import SwiftUI

/// A text field on paper, 80 tall; the marker line turns blue while focused (board C3k). An
/// optional picture sits before the text (S1: the kid's face 40; S2: the school picture 48).
public struct CrayonField<Leading: View>: View {
    private let placeholder: String
    private let isSecure: Bool
    private let leading: Leading
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    /// `isSecure` hides what is typed (keys, codes).
    public init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false,
                @ViewBuilder leading: () -> Leading) {
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.leading = leading()
        _text = text
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            leading
            field.focused($isFocused)
        }
        .crayonType(.body)
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

extension CrayonField where Leading == EmptyView {
    public init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false) {
        self.init(placeholder, text: text, isSecure: isSecure) { EmptyView() }
    }
}
