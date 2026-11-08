import SwiftUI

/// An open marker line through `points`, in the view's own coordinates: one wobbly pass with round
/// caps (the way strip's road and tree trunks, a hill's top edge). Give it the frame the points
/// were measured in.
public struct CrayonLine: View {
    let points: [CGPoint]
    let marker: MarkerStyle
    let color: Color
    let seed: UInt32

    public init(_ points: [CGPoint], marker: MarkerStyle = .standard, color: Color = .init(white: 0.12),
                seed: UInt32) {
        self.points = points
        self.marker = marker
        self.color = color
        self.seed = seed
    }

    public var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.addLines(CrayonGeometry.markerLine(points, marker: marker, seed: seed))
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: marker.width, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
