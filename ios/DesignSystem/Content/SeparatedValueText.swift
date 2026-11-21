import SwiftUI

/// Spec "Sizing → Text that does not fit": a value line joined by " · " stays on one line when it fits, else wraps
/// at a separator onto at most 2 lines ("walk 10 min ·" / "ride 10 min"); it never clips mid-word.
public struct SeparatedValueText: View {
    private let parts: [String]
    private let type: CrayonType
    private let separator = " · " // copy-ok: a separator

    public init(_ text: String, type: CrayonType = .caption) {
        parts = text.components(separatedBy: " · ") // copy-ok: a separator
        self.type = type
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(parts.joined(separator: separator)).crayonType(type).lineLimit(1).fixedSize()
            ForEach((1..<max(parts.count, 2)).reversed(), id: \.self) { split in
                VStack(alignment: .leading, spacing: 0) {
                    Text(parts.prefix(split).joined(separator: separator) + " ·").crayonType(type) // copy-ok: a separator
                        .lineLimit(1).fixedSize()
                    Text(parts.dropFirst(split).joined(separator: separator)).crayonType(type).lineLimit(1).fixedSize()
                }
            }
            Text(parts.joined(separator: separator)).crayonType(type).lineLimit(2)
        }
    }
}
