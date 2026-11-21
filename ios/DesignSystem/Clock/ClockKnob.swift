import CrayonKit
import SwiftUI

/// A knob on the C6 edit clock's rim (spec "C6 · Our day"): 36 drawn (× s), and its touch area is
/// the drawn knob (spec "Sizing → Touch"). White at rest, pick blue with a ring while dragged, grey
/// with a padlock when the edge is locked (school).
public struct ClockKnob: View {
    public enum State: Equatable, Sendable { case idle, dragging, locked }

    public static let size: CGFloat = 36

    private let state: State
    @Environment(\.sizing) private var sizing

    public init(_ state: State) {
        self.state = state
    }

    public var body: some View {
        let size = sizing(Self.size)
        ZStack {
            CrayonSurface(.circle, fill: CrayonFill(color: fill, hachure: nil),
                          marker: MarkerStyle(width: 3.5, roughness: 0.6, bowing: 0.6),
                          markerColor: CrayonColor.pictureOutline, seed: CrayonStyle.Seed.knob)
                .frame(width: size, height: size)
            if state == .locked {
                // Board C6: a hand-drawn padlock filling most of the light knob.
                MarkerIcon(.lock, size: sizing(22), color: CrayonColor.pictureInk)
            }
        }
        .frame(width: size, height: size)
        // The ring while dragged draws outside the knob and never moves it or takes touches.
        .overlay {
            if state == .dragging {
                CrayonSurface(.circle, fill: nil, marker: MarkerStyle(width: 3, roughness: 0.6, bowing: 0.6),
                              markerColor: CrayonColor.pickBlue, seed: CrayonStyle.Seed.knob + 1)
                    .frame(width: size + sizing(16), height: size + sizing(16))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Circle())
    }

    private var fill: Color {
        switch state {
        case .idle: CrayonColor.pictureGround
        case .dragging: CrayonColor.pickBlue
        case .locked: CrayonColor.softText.opacity(0.2)
        }
    }
}
