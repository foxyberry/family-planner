import SwiftUI

/// One bundle on the Before card (board F2): its name, on when it is on the list.
public struct BundleChip: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isOn: Bool

    public init(id: UUID, name: String, isOn: Bool) {
        self.id = id
        self.name = name
        self.isOn = isOn
    }
}

/// Board F2 / F2k (issue 024, layout v77): an outing's before list. A `FormCard` 640 × 580: "Bundles"
/// over the shown kid's bundles as pills (multi-pick, picked hatched and bold), then "Bring" over the
/// caller's Bring picker. With more than one kid, the kid tabs sit right of the title (F2k).
public struct BeforeCard<KidID: Hashable, Bring: View>: View {
    public static var size: CGSize { CGSize(width: 640, height: 580) }

    private let title: String
    private let kidTabs: [(KidID, String, KidFace.Badge?)]
    private let kid: Binding<KidID>?
    private let bundlesCaption: String
    private let chips: [BundleChip]
    private let bringCaption: String
    private let done: String
    private let cancel: String
    private let onToggle: (UUID) -> Void
    private let onDone: () -> Void
    private let onCancel: () -> Void
    private let bring: Bring
    @Environment(\.sizing) private var sizing

    /// `kid` nil (one kid) shows no tabs.
    public init(title: String, kidTabs: [(KidID, String, KidFace.Badge?)], kid: Binding<KidID>?, bundlesCaption: String,
                chips: [BundleChip], bringCaption: String, done: String, cancel: String, onToggle: @escaping (UUID) -> Void,
                onDone: @escaping () -> Void, onCancel: @escaping () -> Void, @ViewBuilder bring: () -> Bring) {
        self.title = title
        self.kidTabs = kidTabs
        self.kid = kid
        self.bundlesCaption = bundlesCaption
        self.chips = chips
        self.bringCaption = bringCaption
        self.done = done
        self.cancel = cancel
        self.onToggle = onToggle
        self.onDone = onDone
        self.onCancel = onCancel
        self.bring = bring()
    }

    public var body: some View {
        FormCard(title: title, size: Self.size, done: done, cancel: cancel, onDone: onDone, onCancel: onCancel) {
            if let kid, !kidTabs.isEmpty {
                CrayonTabs(selection: kid, items: kidTabs, compact: true)
            }
        } content: {
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                Text(bundlesCaption).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                PillToggleGrid(controlWidth: sizing(Self.size.width - 80)) {
                    ForEach(chips) { chip in
                        PillToggle(chip.name, isOn: chip.isOn) { onToggle(chip.id) }
                    }
                }
                Text(bringCaption).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                bring
            }
        }
    }
}
