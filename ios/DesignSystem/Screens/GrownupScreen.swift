import SwiftUI

/// Frame for parent screens (board 0f / C3k): the header and the primary button stay put,
/// only the middle scrolls. When the keyboard opens, the button rides just above it and the
/// focused field is scrolled into view.
public struct GrownupScreen<Header: View, Content: View, Action: View>: View {
    private let header: Header
    private let content: Content
    private let primaryAction: Action

    public init(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content,
                @ViewBuilder primaryAction: () -> Action) {
        self.header = header()
        self.content = content()
        self.primaryAction = primaryAction()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(maxWidth: .infinity,
                       minHeight: GridMetrics.headerBottom - GridMetrics.headerTop,
                       alignment: .leading)
                .padding(.top, GridMetrics.headerTop)
                .padding(.horizontal, GridMetrics.margin)
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, GridMetrics.margin)
                    .padding(.vertical, Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            primaryAction
                .padding(.horizontal, GridMetrics.margin)
                .padding(.vertical, Spacing.m)
                .frame(maxWidth: .infinity)
                .background(CrayonColor.paper)
        }
        .background(CrayonColor.paper)
        .foregroundStyle(CrayonColor.ink)
    }
}
