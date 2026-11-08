import CrayonKit
import SwiftUI

/// A knob on the C6 edit clock's rim (spec "C6 · Our day"): 36 pt drawn, 64 pt to touch. White at
/// rest, pick blue with a ring while dragged, grey with a padlock when the edge is locked (school).
public struct ClockKnob: View {
    public enum State: Equatable, Sendable { case idle, dragging, locked }

    public static let size: CGFloat = 36
    public static let touch: CGFloat = 64

    private let state: State

    public init(_ state: State) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            if state == .dragging {
                CrayonSurface(.circle, fill: nil, marker: MarkerStyle(width: 3, roughness: 0.6, bowing: 0.6),
                              markerColor: CrayonColor.pickBlue, seed: CrayonStyle.Seed.knob + 1)
                    .frame(width: Self.size + 16, height: Self.size + 16)
            }
            CrayonSurface(.circle, fill: CrayonFill(color: fill, hachure: nil),
                          marker: MarkerStyle(width: 3.5, roughness: 0.6, bowing: 0.6), seed: CrayonStyle.Seed.knob)
                .frame(width: Self.size, height: Self.size)
            if state == .locked {
                Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(CrayonColor.ink)
            }
        }
        .frame(width: Self.touch, height: Self.touch)
        .contentShape(Circle())
    }

    private var fill: Color {
        switch state {
        case .idle: CrayonColor.card
        case .dragging: CrayonColor.pickBlue
        case .locked: CrayonColor.softText.opacity(0.35)
        }
    }
}
