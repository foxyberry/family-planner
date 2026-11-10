import CrayonKit
import SwiftUI

/// A form row's card (boards F1–F4): centred over a dim layer, a head title, the row's choices 16
/// below, then Done (`InkButton` 200 × 80) and Cancel (body bold, soft) at the bottom left. A tap on
/// the dim layer is Cancel. Padding 40 at the sides, 36 at the top; the card is at least `size` and
/// grows with its content (Bring's "More").
public struct FormCard<Content: View>: View {
    private let title: String
    private let size: CGSize
    private let done: String
    private let cancel: String
    private let onDone: () -> Void
    private let onCancel: () -> Void
    private let content: Content

    public init(title: String, size: CGSize, done: String, cancel: String, onDone: @escaping () -> Void,
                onCancel: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.size = size
        self.done = done
        self.cancel = cancel
        self.onDone = onDone
        self.onCancel = onCancel
        self.content = content()
    }

    public var body: some View {
        ZStack {
            CrayonColor.dim.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                content
                Spacer(minLength: 0)
                HStack(spacing: Spacing.l) {
                    InkButton(done, height: 80, action: onDone).frame(width: 200)
                    Button(action: onCancel) {
                        Text(cancel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText)
                            .frame(minHeight: 80)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, 36)
            .padding(.bottom, Spacing.m)
            .frame(width: size.width, alignment: .topLeading)
            .frame(minHeight: size.height, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.formCard)
        }
    }
}

/// One choice of a pick list (boards F3 Ends, F4 No school days): a 40 check (blue with a tick when
/// picked, an empty ring otherwise), its label (body, bold when picked) and an optional caption under
/// it; 56 tall.
public struct PickRow: View {
    private let title: String
    private let caption: String?
    private let isPicked: Bool
    private let action: () -> Void

    public init(_ title: String, caption: String? = nil, isPicked: Bool, action: @escaping () -> Void) {
        self.title = title
        self.caption = caption
        self.isPicked = isPicked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.s) {
                CheckMark(isDone: isPicked, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).crayonType(.body, bold: isPicked).foregroundStyle(CrayonColor.ink)
                    if let caption {
                        Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
