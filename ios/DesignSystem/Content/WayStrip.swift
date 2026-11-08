import CrayonKit
import KitArt
import SwiftUI

/// The way to the next outing (board A2-MVP, "Way strip"): a crayon meadow with hills and trees,
/// home on its stem at the left, the destination on its stem at the right, a gently waving road
/// between them, and the mover (bus, car, taxi, shoe) placed by the clock (`progress` 0…1, from
/// State). A card names the outing. By bus or shuttle the road has stops (a passed stop turns ink)
/// and the home stop reads "Our stop"; otherwise "Home". Drawn in the board's 1248 × 340 frame and
/// scaled to fit.
public struct WayStrip: View {
    private let destination: KitSlot
    private let mover: KitSlot
    private let progress: Double
    private let homeLabel: String
    private let destinationLabel: String
    private let showsStops: Bool
    private let cardTitle: String
    private let cardCaption: String?
    private let owner: (badge: KidFace.Badge, name: String)?
    /// The empty look: no trip left today, so only home on its stem and a card.
    private let isHomeAllDay: Bool

    /// A trip: `owner` is the kid whose outing it is; the card starts with their face.
    public init(destination: KitSlot, mover: KitSlot, progress: Double, homeLabel: String, destinationLabel: String,
                showsStops: Bool, cardTitle: String, cardCaption: String,
                owner: (badge: KidFace.Badge, name: String)? = nil) {
        self.destination = destination
        self.mover = mover
        self.progress = min(max(progress, 0), 1)
        self.homeLabel = homeLabel
        self.destinationLabel = destinationLabel
        self.showsStops = showsStops
        self.cardTitle = cardTitle
        self.cardCaption = cardCaption
        self.owner = owner
        isHomeAllDay = false
    }

    /// The strip's empty look (no outing left today for any kid): the same meadow, home on its
    /// stem in the middle, and a card ("Home all day") with no face.
    public init(homeAllDay title: String) {
        destination = .home
        mover = .home
        progress = 0
        homeLabel = ""
        destinationLabel = ""
        showsStops = false
        cardTitle = title
        cardCaption = nil
        owner = nil
        isHomeAllDay = true
    }

    // Board coordinates (spec A2-MVP "Way strip").
    static let size = CGSize(width: 1248, height: 340)
    static let homeX: CGFloat = 150
    static let destinationX: CGFloat = 1100
    static let stopXs: [CGFloat] = [430, 640, 850]
    static let moverStart: CGFloat = 240
    static let moverEnd: CGFloat = 1010

    /// The road's centre line: two gentle waves from x 40 to 1208.
    static func roadY(_ x: CGFloat) -> CGFloat { 250 + 16 * sin(2 * .pi * (x - 40) / 584) }

    static let roadPoints: [CGPoint] = stride(from: CGFloat(40), through: 1208, by: 16).map { CGPoint(x: $0, y: roadY($0)) }

    public var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.size.width, geometry.size.height / Self.size.height)
            board
                .frame(width: Self.size.width, height: Self.size.height)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
    }

    private var moverX: CGFloat { Self.moverStart + (Self.moverEnd - Self.moverStart) * progress }

    @ViewBuilder private var board: some View {
        if isHomeAllDay {
            ZStack(alignment: .topLeading) {
                scenery
                stems([(Self.homeAllDayX, 250)])
                picture(KitIcon(.home, size: 150), slot: .home, size: 150, x: Self.homeAllDayX, stemFoot: 250)
                // At (120, 38), clear of the house (549–699 × 52–202).
                card.fixedSize().offset(x: 120, y: 38)
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        } else {
            tripBoard
        }
    }

    static let homeAllDayX: CGFloat = 624

    private var tripBoard: some View {
        ZStack(alignment: .topLeading) {
            scenery
            stems([(Self.homeX, Self.homeStemFoot), (Self.destinationX, Self.destinationStemFoot)])
            road
            stops
            picture(KitIcon(.home, size: 150), slot: .home, size: 150, x: Self.homeX, stemFoot: Self.homeStemFoot)
            picture(KitIcon(destination, size: 120), slot: destination, size: 120, x: Self.destinationX,
                    stemFoot: Self.destinationStemFoot)
            label(homeLabel, x: Self.homeX)
            label(destinationLabel, x: Self.destinationX)
            moverView
            tripCard
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    // MARK: Scenery

    private static let hills: [(a: CGFloat, b: CGFloat, h: CGFloat)] = [(230, 520, 86), (600, 860, 70), (900, 1210, 92)]
    private static let trees: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [(330, 128, 24), (760, 140, 22),
                                                                        (470, 296, 20), (960, 296, 20)]

    private var scenery: some View {
        ZStack(alignment: .topLeading) {
            CrayonSurface(.roundedRect(cornerRadius: 36),
                          fill: CrayonFill(color: CrayonColor.meadow,
                                           hachure: HachureStyle(degrees: -35, gap: 12, washOpacity: 0.22)),
                          markerColor: CrayonColor.marker, seed: CrayonStyle.Seed.way)
                .frame(width: 1240 + 2 * MarkerStyle.standard.inset, height: 332 + 2 * MarkerStyle.standard.inset)
                .offset(x: 4 - MarkerStyle.standard.inset, y: 4 - MarkerStyle.standard.inset)
            ForEach(Self.hills.indices, id: \.self) { index in
                let hill = Self.hills[index]
                CrayonSurface(.hill, fill: CrayonFill(color: CrayonColor.hillGreen,
                                                      hachure: HachureStyle(degrees: 30, gap: 7, washOpacity: 0.3)),
                              marker: MarkerStyle(width: 0, roughness: 1.2, bowing: 1.4), markerColor: .clear,
                              seed: CrayonStyle.Seed.way + UInt32(10 + index))
                    .frame(width: hill.b - hill.a, height: hill.h)
                    .offset(x: hill.a, y: 170 - hill.h)
                CrayonLine(Self.hillTop(hill), marker: .thin.with(width: 3), color: CrayonColor.marker,
                           seed: CrayonStyle.Seed.way + UInt32(20 + index))
            }
            ForEach(Self.trees.indices, id: \.self) { index in
                let tree = Self.trees[index]
                CrayonLine([CGPoint(x: tree.x, y: tree.y + tree.r - 4), CGPoint(x: tree.x, y: tree.y + tree.r + 18)],
                           marker: .standard.with(width: 5), color: CrayonColor.marker,
                           seed: CrayonStyle.Seed.way + UInt32(30 + index))
                CrayonSurface(.circle, fill: CrayonFill(color: CrayonColor.leaf,
                                                        hachure: HachureStyle(degrees: -40, gap: 4)),
                              markerColor: CrayonColor.marker, seed: CrayonStyle.Seed.way + UInt32(40 + index))
                    .frame(width: 2 * (tree.r + MarkerStyle.standard.inset), height: 2 * (tree.r + MarkerStyle.standard.inset))
                    .offset(x: tree.x - tree.r - MarkerStyle.standard.inset, y: tree.y - tree.r - MarkerStyle.standard.inset)
            }
        }
    }

    /// The hill's arc only (no base line), sampled along the same quadratic curve as `.hill`.
    private static func hillTop(_ hill: (a: CGFloat, b: CGFloat, h: CGFloat)) -> [CGPoint] {
        let mid = (hill.a + hill.b) / 2, control = 170 - 2 * hill.h
        return stride(from: CGFloat(0), through: 1, by: 1.0 / 24).map { t in
            let u = 1 - t
            return CGPoint(x: u * u * hill.a + 2 * u * t * mid + t * t * hill.b,
                           y: u * u * 170 + 2 * u * t * control + t * t * 170)
        }
    }

    // MARK: Road, stems, stops

    /// Stems start at the top edge of their own stop marker (home r 28, destination r 15), so both
    /// look the same length wherever the wave puts the stop.
    static var homeStemFoot: CGFloat { roadY(homeX) - 28 }
    static var destinationStemFoot: CGFloat { roadY(destinationX) - 15 }
    static let stemLength: CGFloat = 32

    /// Dotted stems 32 long from their foot up, dashes 5 long every 10.
    private func stems(_ feet: [(x: CGFloat, foot: CGFloat)]) -> some View {
        Canvas { context, _ in
            var path = Path()
            for (x, foot) in feet {
                var y = foot - Self.stemLength
                while y + 5 <= foot {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + 5))
                    y += 10
                }
            }
            context.stroke(path, with: .color(CrayonColor.marker), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
        .accessibilityHidden(true)
    }

    private var road: some View {
        ZStack {
            CrayonLine(Self.roadPoints, marker: MarkerStyle(width: 28, roughness: 1, bowing: 0.6),
                       color: CrayonColor.marker, seed: CrayonStyle.Seed.way + 50)
            CrayonLine(Self.roadPoints, marker: MarkerStyle(width: 17, roughness: 1.3, bowing: 0.6),
                       color: CrayonColor.leaf, seed: CrayonStyle.Seed.way + 51)
        }
    }

    private var stops: some View {
        ZStack(alignment: .topLeading) {
            if showsStops {
                ForEach(Self.stopXs.indices, id: \.self) { index in
                    let x = Self.stopXs[index]
                    let passed = moverX > x
                    stop(x: x, radius: 15, fill: passed ? CrayonStyle.ink : CrayonStyle.paper,
                         width: passed ? 3.5 : 4.5, seed: CrayonStyle.Seed.way + UInt32(60 + index))
                }
            }
            stop(x: Self.destinationX, radius: 15, fill: CrayonStyle.paper, width: 4.5, seed: CrayonStyle.Seed.way + 64)
            stop(x: Self.homeX, radius: 28, fill: CrayonStyle.paper, width: 6, seed: CrayonStyle.Seed.way + 65)
            stop(x: Self.homeX, radius: 11, fill: CrayonStyle.ink, width: 3, seed: CrayonStyle.Seed.way + 66)
        }
    }

    private func stop(x: CGFloat, radius: CGFloat, fill: CrayonFill, width: CGFloat, seed: UInt32) -> some View {
        let marker = MarkerStyle.standard.with(width: width), outer = radius + marker.inset
        return CrayonSurface(.circle, fill: fill, marker: marker, markerColor: CrayonColor.marker, seed: seed)
            .frame(width: 2 * outer, height: 2 * outer)
            .offset(x: x - outer, y: Self.roadY(x) - outer)
    }

    // MARK: Pictures, labels, mover, card

    /// A picture standing on its stem: its drawn bottom (not its box) on the stem top.
    private func picture(_ view: some View, slot: KitSlot, size: CGFloat, x: CGFloat, stemFoot: CGFloat) -> some View {
        let bottom = size * BundledKitArt().drawnBottom(for: slot)
        return view.frame(width: size, height: size)
            .offset(x: x - size / 2, y: stemFoot - Self.stemLength - bottom)
    }

    private func label(_ text: String, x: CGFloat) -> some View {
        Text(text).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink)
            .multilineTextAlignment(.center)
            .frame(width: 200)
            .offset(x: x - 100, y: Self.roadY(x) + 34)
    }

    /// Bus 120, car or taxi 104, shoe 96; the box bottom sits 20 below the road line.
    private var moverSize: CGFloat {
        switch mover {
        case .busDouble, .busSingle, .busShuttle: 120
        case .shoe: 96
        default: 104
        }
    }

    private var moverView: some View {
        let size = moverSize, x = moverX
        return DrivingKitIcon(mover, size: size)
            .frame(width: size, height: size)
            .offset(x: x - size / 2, y: Self.roadY(x) + 20 - size)
    }

    /// The trip card sits over the hills, centred across the strip, 38 from the top.
    private var tripCard: some View {
        card.frame(width: Self.size.width, alignment: .center).offset(y: 38)
    }

    private var card: some View {
        HStack(spacing: Spacing.m) {
            if let owner {
                KidFace(owner.badge, name: owner.name, size: 40)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(cardTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let cardCaption {
                    Text(cardCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.sm)
        .crayonBackground(.roundedRect(cornerRadius: 18), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 21)
        .fixedSize()
    }
}

private extension MarkerStyle {
    func with(width: CGFloat) -> MarkerStyle { MarkerStyle(width: width, roughness: roughness, bowing: bowing) }
    /// How far `CrayonSurface` pulls a shape in from its frame so the wobble is never clipped; the
    /// frame grows by this so the drawn shape keeps the board's size.
    var inset: CGFloat { width / 2 + roughness + bowing }
}
