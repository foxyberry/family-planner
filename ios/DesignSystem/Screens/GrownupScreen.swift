import SwiftUI

/// Frame for parent screens (boards C1–C6, layout v4; C3k): the header and the primary button
/// stay put, only the middle scrolls. When the keyboard opens, the button rides just above it and
/// the focused field is scrolled into view. It also owns the paper background and hides the system
/// navigation bar, so every grown-up screen uses the crayon Back button (`GrownupHeader`).
/// Everything sits on `GrownupLayout`'s lines: the header at 48 and 64 … 1312, the content from
/// 176 between 64 and 1312 (the form card 64–882, the side column 930–1312), and the primary
/// action in the side column's foot (930, 872, 382 × 96).
public struct GrownupScreen<Header: View, Content: View, Action: View>: View {
    private let header: Header
    private let content: (GrownupLayout) -> Content
    private let primaryAction: (GrownupLayout) -> Action

    public init(@ViewBuilder header: () -> Header, @ViewBuilder content: @escaping (GrownupLayout) -> Content,
                @ViewBuilder primaryAction: @escaping (GrownupLayout) -> Action) {
        self.header = header()
        self.content = content
        self.primaryAction = primaryAction
    }

    /// For content that does not need the lines.
    public init(@ViewBuilder header: () -> Header, @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder primaryAction: @escaping () -> Action) {
        self.init(header: header, content: { _ in content() }, primaryAction: { _ in primaryAction() })
    }

    @Environment(\.sizing) private var sizing

    public var body: some View {
        let layout = GrownupLayout(sizing: sizing)
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(maxWidth: .infinity, minHeight: layout.back.height, alignment: .leading)
                .padding(.top, layout.back.minY)
                .padding(.leading, layout.back.minX)
                .padding(.trailing, sizing.width - layout.right)
            ScrollView {
                content(layout)
                    // Cards inset their rows 40 (x 104) and rows put their controls on 232.
                    .environment(\.cardInset, layout.formInset)
                    .environment(\.formLabelWidth, layout.labelWidth)
                    // Exactly 64 … 1312 wide, so a long line can never push the card off 64.
                    .frame(width: layout.side.maxX - layout.form.minX, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, layout.form.minX)
                    .padding(.top, layout.contentTop - layout.back.maxY)
                    // The last rows can scroll clear of the action button (from 872).
                    .padding(.bottom, sizing.height - layout.action.minY)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // The action button sits in the side column's foot (930, 872, 382 × 96), so the form card
        // runs down beside it as on the boards; with the keyboard open it rides above the keyboard.
        .overlay(alignment: .bottomTrailing) {
            // Paper behind the button (side column only), so side rows scroll under it cleanly.
            primaryAction(layout)
                .frame(width: layout.action.width)
                .padding(.top, sizing.space(Spacing.s))
                .padding(.bottom, layout.bottomInset)
                .background(CrayonColor.paper)
                .padding(.trailing, sizing.width - layout.action.maxX)
        }
        // Board = screen: the header band starts at y 48 from the top of the glass; the status bar
        // sits over the empty band above it. The bottom inset counts from the glass too.
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .background(CrayonColor.paper.ignoresSafeArea())
        .foregroundStyle(CrayonColor.ink)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension EnvironmentValues {
    /// The padding inside a `PaperCard` (24; grown-up screens: 40, so rows start on 104).
    @Entry public var cardInset: CGFloat = Spacing.m
    /// A grown-up form's label column (104 … 232); `nil` keeps `ListRow`'s own 120 + gap.
    @Entry public var formLabelWidth: CGFloat? = nil
    /// Replaces the "Grown-ups only" header caption during the relock countdown ("Locks in 0:30").
    @Entry public var relockCaption: String? = nil
}
