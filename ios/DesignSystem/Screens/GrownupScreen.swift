import SwiftUI

/// Frame for parent screens (board 0f / C3k): the header and the primary button stay put,
/// only the middle scrolls. When the keyboard opens, the button rides just above it and the
/// focused field is scrolled into view. It also owns the paper background and hides the system
/// navigation bar, so every grown-up screen uses the crayon Back button (`GrownupHeader`).
/// Content and the primary action get the 12-column grid of the real screen width.
public struct GrownupScreen<Header: View, Content: View, Action: View>: View {
    private let header: Header
    private let content: (GridMetrics) -> Content
    private let primaryAction: (GridMetrics) -> Action

    public init(@ViewBuilder header: () -> Header, @ViewBuilder content: @escaping (GridMetrics) -> Content,
                @ViewBuilder primaryAction: @escaping (GridMetrics) -> Action) {
        self.header = header()
        self.content = content
        self.primaryAction = primaryAction
    }

    /// For content that does not need the grid.
    public init(@ViewBuilder header: () -> Header, @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder primaryAction: @escaping () -> Action) {
        self.init(header: header, content: { _ in content() }, primaryAction: { _ in primaryAction() })
    }

    public var body: some View {
        GeometryReader { geometry in
            let grid = GridMetrics(width: geometry.size.width)
            VStack(alignment: .leading, spacing: 0) {
                header
                    .frame(maxWidth: .infinity,
                           minHeight: GridMetrics.headerBottom - GridMetrics.headerTop,
                           alignment: .leading)
                    .padding(.top, GridMetrics.headerTop)
                    .padding(.horizontal, GridMetrics.margin)
                ScrollView {
                    content(grid)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GridMetrics.margin)
                        .padding(.vertical, Spacing.m)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                primaryAction(grid)
                    .padding(.horizontal, GridMetrics.margin)
                    .padding(.vertical, Spacing.m)
                    .frame(maxWidth: .infinity)
                    .background(CrayonColor.paper)
            }
        }
        .background(CrayonColor.paper.ignoresSafeArea())
        .foregroundStyle(CrayonColor.ink)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension EnvironmentValues {
    /// Replaces the "Grown-ups only" header caption during the relock countdown ("Locks in 0:30").
    @Entry public var relockCaption: String? = nil
}
