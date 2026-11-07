#if DEBUG
import DesignSystem
import KitArt
import SwiftUI

/// Debug builds only: the floating bug bubble over every screen, the layout grid when it is on,
/// and the menu. Touches outside the bubble go through to the app.
public struct DebugOverlay: View {
    @Bindable var model: DebugModel

    public init(model: DebugModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if model.settings.showsLayoutGrid {
                    LayoutGridOverlay(size: geometry.size)
                }
                DebugBubble(model: model, screen: geometry.size)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $model.isMenuShown) {
            DebugMenu(model: model)
        }
    }
}

/// Drag it anywhere; it settles on the nearer edge, or tucks half away when pushed into it.
/// Tap a tucked bubble to bring it out, tap again for the menu.
struct DebugBubble: View {
    @Bindable var model: DebugModel
    let screen: CGSize
    @State private var dragLocation: CGPoint?

    static let size: CGFloat = 64

    var body: some View {
        let dock = model.settings.bubble
        let resting = dock.center(in: screen, size: Self.size)
        VStack(spacing: 2) {
            KitIcon(.debugLadybug, size: model.isTravelling ? 36 : 44)
            if model.isTravelling {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(model.core.now(), format: .dateTime.weekday(.abbreviated).hour(.twoDigits(amPM: .omitted)).minute())
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: Self.size, height: Self.size)
        .background(Circle().fill(model.isTravelling ? Color.orange : Color.black.opacity(0.75)))
        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
        .shadow(radius: 4)
        .opacity(dock.tucked && dragLocation == nil ? 0.55 : 1)
        .contentShape(Circle())
        .position(dragLocation ?? resting)
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
                .onChanged { dragLocation = $0.location }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        model.settings.bubble = BubbleDock(drop: value.location, screen: screen, size: Self.size)
                        dragLocation = nil
                    }
                }
        )
        .onTapGesture {
            if dock.tucked {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { model.settings.bubble.tucked = false }
            } else {
                model.isMenuShown = true
            }
        }
        .frame(width: screen.width, height: screen.height)
        .coordinateSpace(.named(Self.space))
        .accessibilityLabel("Debug menu")
        .accessibilityAddTraits(.isButton)
    }

    static let space = "debug-bubble"
}

/// The 12-column grid and the header/content bands of `KidScreen` (`GridMetrics`), plus the screen size.
struct LayoutGridOverlay: View {
    let size: CGSize

    var body: some View {
        let grid = GridMetrics(width: size.width)
        ZStack(alignment: .topLeading) {
            ForEach(0..<GridMetrics.columns, id: \.self) { column in
                Rectangle()
                    .fill(Color.red.opacity(0.10))
                    .frame(width: grid.columnWidth, height: size.height)
                    .offset(x: grid.x(column: column))
            }
            ForEach(bands, id: \.self) { y in
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: size.width, height: 1)
                    .offset(y: y)
            }
            Text("\(Int(size.width)) × \(Int(size.height)) pt · column \(grid.columnWidth, format: .number.precision(.fractionLength(1))) · gutter \(Int(GridMetrics.gutter)) · margin \(Int(GridMetrics.margin))")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.7), in: Capsule())
                .foregroundStyle(.white)
                .frame(width: size.width)
                .offset(y: 4)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var bands: [CGFloat] {
        [GridMetrics.headerTop, GridMetrics.headerBottom, GridMetrics.contentTop,
         size.height - GridMetrics.contentBottomInset]
    }
}
#endif
