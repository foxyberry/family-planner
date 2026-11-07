import CrayonKit
import SwiftUI

/// The one primary action on a screen: black marker fill, white text, 96 tall.
public struct InkButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .crayonType(.head)
                .foregroundStyle(CrayonColor.card)
                .frame(maxWidth: .infinity, minHeight: 96)
                .crayonBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.ink, seed: CrayonStyle.Seed.inkButton)
        }
        .buttonStyle(.plain)
    }
}
