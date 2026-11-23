import CrayonKit
import SwiftUI

/// A form row's card (boards F1–F4): centred over a dim layer, a head title, the row's choices 16
/// below, then Done (`InkButton` 200 × 80) and Cancel (body bold, soft) at the bottom left. A tap on
/// the dim layer is Cancel. Padding 40 at the sides, 36 at the top; the card is at least `size` (a
/// board size, × s) and grows with its content (Bring's "More"). An `accessory` sits right of the
/// title on its line (board F2k: the kid tabs).
public struct FormCard<Content: View, Accessory: View>: View {
    private let title: String
    private let accessory: Accessory
    private let size: CGSize
    private let done: String
    private let cancel: String
    private let onDone: () -> Void
    private let onCancel: () -> Void
    private let content: Content
    @Environment(\.sizing) private var sizing

    public init(title: String, size: CGSize, done: String, cancel: String, onDone: @escaping () -> Void,
                onCancel: @escaping () -> Void, @ViewBuilder accessory: () -> Accessory,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory()
        self.size = size
        self.done = done
        self.cancel = cancel
        self.onDone = onDone
        self.onCancel = onCancel
        self.content = content()
    }

    public var body: some View {
        ZStack {
            CrayonColor.dim.fullBleed()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
            // Layout v43: the card hugs its content, centred; the buttons sit 8 under it.
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                    HStack(spacing: sizing(Spacing.m)) {
                        Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                        Spacer(minLength: 0)
                        accessory
                    }
                    content
                }
                HStack(spacing: sizing(Spacing.l)) {
                    InkButton(done, height: 80, action: onDone).frame(width: sizing(200))
                    Button(action: onCancel) {
                        Text(cancel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText)
                            .frame(minHeight: sizing(80))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            // Spec "Layout balance": an overlay card pads 32 from its drawn edge.
            .padding(ConfirmCard.padding(sizing))
            .frame(width: sizing(size.width), alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.formCard, tap: .frame)
        }
    }
}

extension FormCard where Accessory == EmptyView {
    /// A card with the title alone on its line.
    public init(title: String, size: CGSize, done: String, cancel: String, onDone: @escaping () -> Void,
                onCancel: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(title: title, size: size, done: done, cancel: cancel, onDone: onDone, onCancel: onCancel,
                  accessory: { EmptyView() }, content: content)
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
    @Environment(\.sizing) private var sizing

    public init(_ title: String, caption: String? = nil, isPicked: Bool, action: @escaping () -> Void) {
        self.title = title
        self.caption = caption
        self.isPicked = isPicked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: sizing(Spacing.s)) {
                CheckMark(isDone: isPicked, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).crayonType(.body, bold: isPicked).foregroundStyle(CrayonColor.ink)
                    if let caption {
                        Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: sizing(56))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
