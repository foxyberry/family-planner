#if DEBUG
import DesignSystem
import KitArt
import SwiftUI

/// Debug builds only: the floating bug bubble over every screen, the layout grid when it is on,
/// and the menu. Touches outside the bubble go through to the app.
public struct DebugOverlay: View {
    @Bindable var model: DebugModel
    private let lines: GridLines

    @Environment(\.sizing) private var sizing

    /// `lines`: which family's board lines the grid draws (kid screens or grown-up screens).
    public init(model: DebugModel, lines: GridLines) {
        self.model = model
        self.lines = lines
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if model.settings.showsLayoutGrid {
                    LayoutGridOverlay(size: geometry.size, sizing: sizing, lines: lines)
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
/// Tap a tucked bubble to bring it out, tap again for the menu (Face ID first on a real iPad).
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
                    Text(verbatim: DebugModel.bubbleText(model.core.now(), calendar: model.calendar))
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
                Task { await model.menuTapped() }
            }
        }
        .frame(width: screen.width, height: screen.height)
        .coordinateSpace(.named(Self.space))
        .accessibilityLabel("Debug menu")
        .accessibilityAddTraits(.isButton)
    }

    static let space = "debug-bubble"
}

/// The board's lines over the screen (spec "Sizing formulas", docs/superpowers/layout): margins
/// 64 / 1312, the morning column 448, the home panel 928 (left-anchored or right-anchored like the
/// screens), and the bands 48 / 128 / 176 / 516 / 536 / 872 / 968; baselines 107 / 584 / 757 dashed.
/// The board lines a screen family shares (docs/superpowers/layout/README.md).
public enum GridLines: Sendable {
    /// Home: 64, 448, 928, 1312; Kid A's fixed baselines 132 … 446 and Kid B's lowest name line 584
    /// (Kid B moves with Kid A's block, layout v8).
    case home
    /// Morning: 64, 172, 448, 1312; the header, strip and bottom bands, baselines 107 / 584 / 757.
    case morning
    /// Grown-up screens: 64, 104, 232, 280, 882, 930, 1312; header, content and action bands.
    case grownup
}

struct LayoutGridOverlay: View {
    let size: CGSize
    let sizing: Sizing
    let lines: GridLines

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(verticals, id: \.self) { x in
                Rectangle().fill(Color.red.opacity(0.7)).frame(width: 1, height: size.height).offset(x: x)
            }
            ForEach(bands, id: \.self) { y in
                Rectangle().fill(Color.blue.opacity(0.6)).frame(width: size.width, height: 1).offset(y: y)
            }
            ForEach(baselines, id: \.self) { y in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.green.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            }
            Text(verbatim: "\(Int(size.width)) × \(Int(size.height)) pt · s \(String(format: "%.3f", sizing.s)) · safe top \(Int(sizing.safeTop))") // copy-ok: debug
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

    private var verticals: [CGFloat] {
        switch lines {
        case .home: [sizing.left(64), sizing.left(448), sizing.left(928), sizing.right(1312)]
        case .morning: [sizing.left(64), sizing.left(172), sizing.left(448), sizing.right(1312)]
        case .grownup: [64, 104, 232, 280, 882].map(sizing.left) + [sizing.right(930), sizing.right(1312)]
        }
    }

    private var bands: [CGFloat] {
        switch lines {
        case .home: [96, 872, 968].map(sizing.y)
        case .morning: [48, 128, 176, 516, 536, 872, 968].map(sizing.y)
        case .grownup: [48, 128, 176, 872, 968].map(sizing.y)
        }
    }

    private var baselines: [CGFloat] {
        switch lines {
        case .home: [132, 187, 301, 402, 446, 584].map(sizing.y)
        case .morning: [107, 584, 757].map(sizing.y)
        case .grownup: [107].map(sizing.y)
        }
    }
}
#endif
