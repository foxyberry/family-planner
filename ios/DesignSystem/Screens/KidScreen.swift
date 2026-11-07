import SwiftUI

/// Frame for every child-facing screen (board 0f): cream paper, the 12-column grid, a fixed
/// header band, and no scrolling. Content that does not fit is clipped, so callers cap their
/// lists with `Capped` instead of adding a scroll view.
public struct KidScreen<Header: View, Body: View>: View {
    private let header: Header
    private let content: (GridMetrics) -> Body

    public init(@ViewBuilder header: () -> Header, @ViewBuilder body: @escaping (GridMetrics) -> Body) {
        self.header = header()
        content = body
    }

    public var body: some View {
        GeometryReader { geometry in
            let grid = GridMetrics(width: geometry.size.width)
            VStack(alignment: .leading, spacing: 0) {
                header
                    .frame(maxWidth: .infinity,
                           minHeight: GridMetrics.headerBottom - GridMetrics.headerTop,
                           maxHeight: GridMetrics.headerBottom - GridMetrics.headerTop,
                           alignment: .leading)
                    .padding(.top, GridMetrics.headerTop)
                content(grid)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, GridMetrics.contentTop - GridMetrics.headerBottom)
                    .padding(.bottom, GridMetrics.contentBottomInset)
            }
            .padding(.horizontal, GridMetrics.margin)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .background(CrayonColor.paper)
        .foregroundStyle(CrayonColor.ink)
    }
}
