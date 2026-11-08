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

/// The kid home screens (boards A1, E1, E3, E3b): an empty header, and the content uses the whole
/// screen because the clock is not on the grid. Still cream paper, no scrolling, clipped.
/// At night (board A1n) the page turns `night`: a 2 s crossfade when the plan changes the look, or,
/// from the sky switch (`wipeFrom`), the new colour spreading as a circle from the switch
/// (300–900 ms). Reduce Motion: a 0.3 s crossfade.
public struct KidFullScreen<Body: View>: View {
    private let look: KidLook
    private let wipeFrom: CGPoint?
    private let content: () -> Body
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page colour under a running wipe; `nil` when no wipe runs.
    @State private var under: KidLook?
    @State private var wipe: CGFloat = 0

    public init(look: KidLook = .day, wipeFrom: CGPoint? = nil, @ViewBuilder content: @escaping () -> Body) {
        self.look = look
        self.wipeFrom = wipeFrom
        self.content = content
    }

    public var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .background { page.ignoresSafeArea() }
            .foregroundStyle(look.ink)
            .onChange(of: look) { old, _ in
                guard wipeFrom != nil, !reduceMotion else { return }
                under = old
                wipe = 0
                withAnimation(.easeInOut(duration: 0.6).delay(0.3)) { wipe = 1 } completion: { under = nil }
            }
    }

    @ViewBuilder private var page: some View {
        if let under, let origin = wipeFrom {
            ZStack {
                under.page
                Circle().fill(look.page)
                    .frame(width: 3200 * wipe, height: 3200 * wipe)
                    .position(origin)
            }
        } else {
            look.page.animation(reduceMotion ? .easeInOut(duration: 0.3) : KidLook.crossfade, value: look)
        }
    }
}
