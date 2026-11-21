import SwiftUI

/// Frame for parent screens (the grown-up boards: G1–G8, C2–C5; C3k): the header and the primary
/// button stay put, only the middle scrolls. When the keyboard opens, the button rides just above it and
/// the focused field is scrolled into view. It also owns the paper background and hides the system
/// navigation bar, so every grown-up screen uses the crayon Back button (`GrownupHeader`).
/// Everything sits on `GrownupLayout`'s lines (board × s): the header at 44 and 40 … 1336, the
/// content from 148 (the form card 40–840, the side column 864–1336), and the primary action in the
/// side column's foot (864, 872, 472 × 96).
/// A row for `GrownupScreen` to bring into view (spec "Add-screen feedback": Save scrolls to the
/// first problem); `request` changes for every new ask, so the same row can be asked for twice.
public struct GrownupScrollTarget: Equatable, Sendable {
    public var id: String
    public var request: Int

    public init(id: String, request: Int) {
        self.id = id
        self.request = request
    }
}

public struct GrownupScreen<Header: View, Content: View, Action: View>: View {
    private let header: Header
    private let content: (GrownupLayout) -> Content
    private let primaryAction: (GrownupLayout) -> Action
    private let scrollTarget: GrownupScrollTarget?
    private let scrolls: Bool

    /// `scrollTarget`: a row (marked with `.id`) to scroll to the middle of the screen.
    /// `scrolls: false` (spec "Scrolling on G1 / G1c / G1d"): the content stays put in the content
    /// box (176 … 968) and its main card and side column scroll on their own (`ScrollColumn`).
    public init(scrollTarget: GrownupScrollTarget? = nil, scrolls: Bool = true, @ViewBuilder header: () -> Header,
                @ViewBuilder content: @escaping (GrownupLayout) -> Content,
                @ViewBuilder primaryAction: @escaping (GrownupLayout) -> Action) {
        self.header = header()
        self.content = content
        self.primaryAction = primaryAction
        self.scrollTarget = scrollTarget
        self.scrolls = scrolls
    }

    /// For content that does not need the lines.
    public init(@ViewBuilder header: () -> Header, @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder primaryAction: @escaping () -> Action) {
        self.init(header: header, content: { _ in content() }, primaryAction: { _ in primaryAction() })
    }

    @Environment(\.sizing) private var sizing
    @Environment(\.keyboardTop) private var keyboardTop

    public var body: some View {
        // Board C3k and spec "Keyboard": the screen ignores the keyboard, so the header never moves;
        // only the form card and the action button follow it, through the layout, from the one
        // keyboard client's decision (`keyboardTop`, docked and > 100 pt).
        screen(GrownupLayout(sizing: sizing, keyboardTop: keyboardTop))
            .ignoresSafeArea(.keyboard)
        .background(CrayonColor.paper.fullBleed())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func screen(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(maxWidth: .infinity, minHeight: layout.back.height, alignment: .leading)
                .padding(.top, layout.back.minY)
                .padding(.leading, layout.back.minX)
                .padding(.trailing, sizing.width - layout.right)
            if scrolls {
                ScrollViewReader { proxy in
                    ScrollView {
                        placed(layout)
                            // The last rows can scroll clear of the action button (from 872).
                            .padding(.bottom, sizing.height - layout.action.minY)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target.id, anchor: .center) }
                    }
                }
            } else {
                placed(layout)
                    .frame(height: layout.form.maxY - layout.back.maxY, alignment: .top)
                Spacer(minLength: 0)
            }
        }
        // The action button sits in the side column's foot (930, 872, 382 × 96), so the form card
        // runs down beside it as on the boards; with the keyboard open it rides above the keyboard.
        .overlay(alignment: .bottomTrailing) {
            // Paper behind the button (side column only), so side rows scroll under it cleanly.
            primaryAction(layout)
                .frame(width: layout.action.width)
                .padding(.top, sizing(Spacing.s))
                .padding(.bottom, layout.bottomInset)
                .background(CrayonColor.paper)
                .padding(.trailing, sizing.width - layout.action.maxX)
        }
        // Board = screen: the header band starts at y 48 from the top of the glass; the status bar
        // sits over the empty band above it. The bottom inset counts from the glass too.
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        // Every edge comes from one board frame (1376 s, centred), also where the screen is hosted
        // outside the app root's frame (a `fullScreenCover`: S2 Data sources, S3 Change buses).
        .frame(width: sizing.width)
        .frame(maxWidth: .infinity)
        .background(CrayonColor.paper.fullBleed())
        .foregroundStyle(CrayonColor.ink)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func placed(_ layout: GrownupLayout) -> some View {
        content(layout)
            // Spec "Layout balance": cards pad 32 from their drawn edge (labels on 78) and rows put
            // their controls on the control line (192).
            .environment(\.cardPadding, sizing.cardPadding)
            .environment(\.formLabelWidth, layout.labelWidth)
            // Exactly 64 … 1312 wide, so a long line can never push the card off 64.
            .frame(width: layout.side.maxX - layout.form.minX, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, layout.form.minX)
            .padding(.top, layout.contentTop - layout.back.maxY)
    }
}

/// One scrolling region of a grown-up screen (spec "Scrolling on G1 / G1c / G1d"): a main card's
/// rows or a side column scroll inside their own frame, never with the rest of the screen. Content
/// that fits shows no bounce and no bar. `scrollTarget` scrolls a row marked with `.id` to the middle.
public struct ScrollColumn<Content: View>: View {
    private let scrollTarget: GrownupScrollTarget?
    private let anchor: UnitPoint
    private let bleed: EdgeInsets
    private let content: Content

    /// `anchor`: where the target row lands (`.top` for a search field, so its list fits above the
    /// keyboard; spec S2s, design session 2026-11-15).
    /// `bleed`: room outside the column where its content may still draw (a card's corner ×,
    /// `EdgeInsets.cardCorner`); a scroll view clips at its frame otherwise.
    public init(scrollTarget: GrownupScrollTarget? = nil, anchor: UnitPoint = .center, bleed: EdgeInsets = EdgeInsets(),
                @ViewBuilder content: () -> Content) {
        self.scrollTarget = scrollTarget
        self.anchor = anchor
        self.bleed = bleed
        self.content = content()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                content.frame(maxWidth: .infinity, alignment: .topLeading).padding(bleed)
            }
            .padding(EdgeInsets(top: -bleed.top, leading: -bleed.leading, bottom: -bleed.bottom, trailing: -bleed.trailing))
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target.id, anchor: anchor) }
            }
        }
    }
}

public extension GrownupLayout {
    /// S2s / G7 with the keyboard up: the list card's height from 8 under the field (at the card's
    /// top inset) down to the column's foot above the keyboard; nil without the keyboard.
    var searchListHeight: CGFloat? {
        guard keyboardTop != nil else { return nil }
        let listTop = contentTop + formInset + sizing.fieldHeight + sizing(Spacing.xs)
        return max(sizing.oneLineRow + 2 * sizing(Spacing.xs), form.maxY - listTop)
    }

}

extension EnvironmentValues {
    /// The padding inside a `PaperCard`, on this screen (24 × s each side by default, `PaperCard`;
    /// grown-up screens: `Sizing.cardPadding`).
    @Entry public var cardPadding: EdgeInsets? = nil
    /// A grown-up form's label column (114, labels 78 → controls 192); `nil` keeps `ListRow`'s own
    /// 120 + gap.
    @Entry public var formLabelWidth: CGFloat? = nil
    /// Replaces the "Grown-ups only" header caption during the relock countdown ("Locks in 0:30").
    @Entry public var relockCaption: String? = nil
}
