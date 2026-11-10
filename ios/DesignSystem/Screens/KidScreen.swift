import SwiftUI

/// The kid home screens (boards A1, E1, E3, E3b): an empty header, and the content uses the whole
/// screen because the clock is not on the grid. Still cream paper, no scrolling, clipped.
/// At night (board A1n) the page turns `night`: a 2 s crossfade when the plan changes the look, or,
/// from the sky switch (`wipeFrom`), the new colour spreading as a circle from the switch
/// (300–900 ms). Reduce Motion: a 0.3 s crossfade.
public struct KidFullScreen<Body: View>: View {
    private let look: KidLook
    private let wipeFrom: CGPoint?
    private let nightTokens: Bool
    private let content: () -> Body
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page colour under a running wipe; `nil` when no wipe runs.
    @State private var under: KidLook?
    @State private var wipe: CGFloat = 0

    /// `nightTokens`: at night the colour tokens take their night values (A2's night board); the kid
    /// home keeps the light ones and draws its night from `KidLook`.
    public init(look: KidLook = .day, wipeFrom: CGPoint? = nil, nightTokens: Bool = false,
                @ViewBuilder content: @escaping () -> Body) {
        self.look = look
        self.wipeFrom = wipeFrom
        self.nightTokens = nightTokens
        self.content = content
    }

    public var body: some View {
        content()
            .modifier(FullScreenFrame())
            .background { page.ignoresSafeArea() }
            .foregroundStyle(look.ink)
            // Kid screens take their night look from `KidLook`, never from the colour tokens.
            .environment(\.colorScheme, nightTokens && look == .night ? .dark : .light)
            // The status bar follows the app's root (`AppView`), which knows what is on top.
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

/// Kid full screens are laid out in full-screen space (spec "Sizing formulas"): y 0 is the top of
/// the glass, the window's whole size, top-leading, clipped. Screens place their regions with
/// `Sizing` (`y`, `left`, `right`, `stretch`), so content never grows or centres the frame.
struct FullScreenFrame: ViewModifier {
    @Environment(\.sizing) private var sizing

    func body(content: Content) -> some View {
        content
            .frame(width: sizing.width, height: sizing.height, alignment: .topLeading)
            .clipped()
            .ignoresSafeArea()
    }
}

