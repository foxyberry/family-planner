import CrayonKit
import KitArt
import SwiftUI

/// The way to the family's next outing (spec "A2 · Morning › Way strip", boards A2, A2t, A2t-w,
/// A3): a straight crayon road, our stop with home in the middle (x 860), the destination at
/// 1150, stops before ours by bus. Three looks share it: the timetable look (one mover placed by
/// the clock, a card with the owner's face), the live look (the buses coming to our stop with
/// their bubbles and the "my bus" legend) and the empty look ("Home all day"). Drawn in the
/// board's 1248 × 340 frame and scaled to fit, keeping its shape; labels, bubbles and cards are
/// set on top at real type sizes.
public struct WayStrip: View {
    /// A bus on the live look: x on the board (from its minutes, in State), its picture and the
    /// words of its bubble.
    public struct LiveBus: Equatable, Sendable, Identifiable {
        public var id: String
        public var x: CGFloat
        public var picture: KitSlot
        public var service: String
        public var minutes: String
        public var isMine: Bool
        public var isTooSoon: Bool
        public var showsBubble: Bool

        public init(id: String, x: CGFloat, picture: KitSlot, service: String, minutes: String, isMine: Bool,
                    isTooSoon: Bool, showsBubble: Bool) {
            self.id = id
            self.x = x
            self.picture = picture
            self.service = service
            self.minutes = minutes
            self.isMine = isMine
            self.isTooSoon = isTooSoon
            self.showsBubble = showsBubble
        }
    }

    /// Everything the live look draws.
    public struct Live: Equatable, Sendable {
        public var buses: [LiveBus]
        public var destination: KitSlot
        public var destinationLabel: String
        public var ourStopLabel: String
        public var owner: KidFace.Badge
        public var ownerName: String
        public var myBus: String
        public var tooSoon: String
        /// The kid's 1st-choice bus number for the legend plate, also when no bus can be caught.
        public var myService: String

        public init(buses: [LiveBus], destination: KitSlot, destinationLabel: String, ourStopLabel: String,
                    owner: KidFace.Badge, ownerName: String, myBus: String, tooSoon: String, myService: String = "") {
            self.myService = myService
            self.buses = buses
            self.destination = destination
            self.destinationLabel = destinationLabel
            self.ourStopLabel = ourStopLabel
            self.owner = owner
            self.ownerName = ownerName
            self.myBus = myBus
            self.tooSoon = tooSoon
        }
    }

    /// The timetable look: one mover at a board x (from State), the stops by bus, the card.
    public struct Trip: Equatable, Sendable {
        public var destination: KitSlot
        public var destinationLabel: String
        public var homeLabel: String
        public var showsStops: Bool
        public var mover: KitSlot
        public var moverX: CGFloat
        public var cardTitle: String
        public var cardCaption: String
        public var owner: KidFace.Badge
        public var ownerName: String

        public init(destination: KitSlot, destinationLabel: String, homeLabel: String, showsStops: Bool,
                    mover: KitSlot, moverX: CGFloat, cardTitle: String, cardCaption: String, owner: KidFace.Badge,
                    ownerName: String) {
            self.destination = destination
            self.destinationLabel = destinationLabel
            self.homeLabel = homeLabel
            self.showsStops = showsStops
            self.mover = mover
            self.moverX = moverX
            self.cardTitle = cardTitle
            self.cardCaption = cardCaption
            self.owner = owner
            self.ownerName = ownerName
        }
    }

    private enum Look: Equatable {
        case trip(Trip)
        case live(Live)
        case homeAllDay(String)
    }

    private let look: Look

    public init(trip: Trip) { look = .trip(trip) }
    public init(live: Live) { look = .live(live) }
    /// The empty look (no outing left today for any kid): ground and trees, home in the middle,
    /// the card ("Home all day") with no face.
    public init(homeAllDay title: String) { look = .homeAllDay(title) }

    // MARK: Board coordinates (1248 × 340)

    public static let size = CGSize(width: 1248, height: 340)
    static let roadY: CGFloat = 240
    static let homeX: CGFloat = 860
    static let destinationX: CGFloat = 1150
    static let stopXs: [CGFloat] = [170, 380, 620]
    static let homeAllDayX: CGFloat = 624
    static let moverBottom: CGFloat = 260
    static let stemLength: CGFloat = 32
    static let labelTop: CGFloat = 274
    static let rightEdge: CGFloat = 1232

    /// A bus's x from its minutes to our stop: 30 min or more at x 60, at our stop at 0.
    public static func liveX(minutes: Int) -> CGFloat { homeX - CGFloat(min(max(minutes, 0), 30)) * 800 / 30 }

    /// Where the mover waits once the outing has started: at the destination's side (x 1070).
    public static let arrivedX: CGFloat = 1070

    /// A car, taxi or walk: waits at x 990 until "leave", then reaches 1070 at the start.
    public static func vehicleX(minute: Int, leave: Int, start: Int) -> CGFloat {
        guard minute > leave, start > leave else { return 990 }
        return 990 + 80 * CGFloat(min(minute - leave, start - leave)) / CGFloat(start - leave)
    }

    public var body: some View {
        // The strip fills its region (64 to 1312 on the screen). Spec "Way strip": the ground and road
        // fill it; x positions follow the strip's width (kx); every size and y follows s (k), so
        // nothing is stretched and the trees stay round.
        GeometryReader { geometry in
            let g = Geo(kx: geometry.size.width / Self.size.width, k: geometry.size.height / Self.size.height)
            ZStack(alignment: .topLeading) {
                board(g)
                texts(kx: g.kx, k: g.k)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
    }

    /// Board units to screen points: x by the strip's width, y and sizes by s.
    struct Geo {
        let kx: CGFloat
        let k: CGFloat
        func x(_ v: CGFloat) -> CGFloat { v * kx }
        func y(_ v: CGFloat) -> CGFloat { v * k }
        func len(_ v: CGFloat) -> CGFloat { v * k }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: self.x(x), y: self.y(y)) }
    }

    // MARK: Drawing (no text)

    @ViewBuilder private func board(_ g: Geo) -> some View {
        ZStack(alignment: .topLeading) {
            scenery(g)
            switch look {
            case let .trip(trip):
                roadAndStops(g, showsStops: trip.showsStops)
                pictures(g, destination: trip.destination)
                mover(g, trip.mover, x: trip.moverX)
            case let .live(live):
                roadAndStops(g, showsStops: true)
                pictures(g, destination: live.destination)
                ForEach(live.buses) { bus in
                    mover(g, bus.picture, x: bus.x)
                        .opacity(bus.isTooSoon ? 0.5 : 1)
                        .animation(.linear(duration: 1), value: bus.x)
                }
            case .homeAllDay:
                stems(g, [(Self.homeAllDayX, 250)])
                picture(g, .home, size: 150, x: Self.homeAllDayX, stemFoot: 250)
            }
        }
    }

    private static let trees: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [(745, 150, 26), (1010, 120, 24),
                                                                        (300, 300, 20), (980, 300, 22)]

    private func scenery(_ g: Geo) -> some View {
        ZStack(alignment: .topLeading) {
            CrayonSurface(.roundedRect(cornerRadius: g.len(36)),
                          fill: CrayonFill(color: CrayonColor.meadow,
                                           hachure: HachureStyle(degrees: -35, gap: 12, washOpacity: 0.22)),
                          markerColor: CrayonColor.marker, seed: CrayonStyle.Seed.way)
                // The ground's visible edge is the strip's edge (64 and 1312 on the screen).
                .frame(width: g.x(Self.size.width), height: g.y(Self.size.height))
            ForEach(Self.trees.indices, id: \.self) { index in
                let tree = Self.trees[index], inset = MarkerStyle.standard.inset, r = g.len(tree.r)
                let centre = g.point(tree.x, tree.y)
                CrayonLine([CGPoint(x: centre.x, y: centre.y + r - g.len(4)),
                            CGPoint(x: centre.x, y: centre.y + r + g.len(18))],
                           marker: .standard.with(width: 5), color: CrayonColor.marker,
                           seed: CrayonStyle.Seed.way + UInt32(30 + index))
                CrayonSurface(.circle, fill: CrayonFill(color: CrayonColor.leaf,
                                                        hachure: HachureStyle(degrees: -40, gap: 4)),
                              markerColor: CrayonColor.marker, seed: CrayonStyle.Seed.way + UInt32(40 + index))
                    .frame(width: 2 * (r + inset), height: 2 * (r + inset))
                    .offset(x: centre.x - r - inset, y: centre.y - r - inset)
            }
        }
    }

    private func roadAndStops(_ g: Geo, showsStops: Bool) -> some View {
        let road = [g.point(28, Self.roadY), g.point(1220, Self.roadY)]
        let homeFoot = Self.roadY - 28, destinationFoot = Self.roadY - 15
        return ZStack(alignment: .topLeading) {
            stems(g, [(Self.homeX, homeFoot), (Self.destinationX, destinationFoot)])
            CrayonLine(road, marker: MarkerStyle(width: g.len(28), roughness: 1, bowing: 0.6), color: CrayonColor.marker,
                       seed: CrayonStyle.Seed.way + 50)
            CrayonLine(road, marker: MarkerStyle(width: g.len(17), roughness: 1.3, bowing: 0.6), color: CrayonColor.leaf,
                       seed: CrayonStyle.Seed.way + 51)
            if showsStops {
                ForEach(Self.stopXs.indices, id: \.self) { index in
                    stop(g, x: Self.stopXs[index], radius: 15, fill: CrayonStyle.paper, width: 4.5,
                         seed: CrayonStyle.Seed.way + UInt32(60 + index))
                }
            }
            stop(g, x: Self.destinationX, radius: 15, fill: CrayonStyle.paper, width: 4.5, seed: CrayonStyle.Seed.way + 64)
            stop(g, x: Self.homeX, radius: 28, fill: CrayonStyle.paper, width: 6, seed: CrayonStyle.Seed.way + 65)
            stop(g, x: Self.homeX, radius: 11, fill: CrayonStyle.ink, width: 3, seed: CrayonStyle.Seed.way + 66)
        }
    }

    private func pictures(_ g: Geo, destination: KitSlot) -> some View {
        ZStack(alignment: .topLeading) {
            picture(g, .home, size: 150, x: Self.homeX, stemFoot: Self.roadY - 28)
            picture(g, destination, size: 120, x: Self.destinationX, stemFoot: Self.roadY - 15)
        }
    }

    /// Dotted stems 32 long from their foot (the top of the stop marker) up, dashes 5 every 10.
    private func stems(_ g: Geo, _ feet: [(x: CGFloat, foot: CGFloat)]) -> some View {
        Canvas { context, _ in
            var path = Path()
            for (x, foot) in feet {
                var y = foot - Self.stemLength
                while y + 5 <= foot {
                    path.move(to: g.point(x, y))
                    path.addLine(to: g.point(x, y + 5))
                    y += 10
                }
            }
            context.stroke(path, with: .color(CrayonColor.marker),
                           style: StrokeStyle(lineWidth: g.len(5), lineCap: .round))
        }
        .accessibilityHidden(true)
    }

    private func stop(_ g: Geo, x: CGFloat, radius: CGFloat, fill: CrayonFill, width: CGFloat, seed: UInt32) -> some View {
        let marker = MarkerStyle.standard.with(width: g.len(width)), outer = g.len(radius) + marker.inset
        return CrayonSurface(.circle, fill: fill, marker: marker, markerColor: CrayonColor.marker, seed: seed)
            .frame(width: 2 * outer, height: 2 * outer)
            .offset(x: g.x(x) - outer, y: g.y(Self.roadY) - outer)
    }

    /// A picture standing on its stem: its drawn bottom (not its box) on the stem top.
    private func picture(_ g: Geo, _ slot: KitSlot, size: CGFloat, x: CGFloat, stemFoot: CGFloat) -> some View {
        let side = g.len(size), bottom = side * BundledKitArt().drawnBottom(for: slot)
        return KitIcon(slot, size: side).frame(width: side, height: side)
            .offset(x: g.x(x) - side / 2, y: g.y(stemFoot - Self.stemLength) - bottom)
    }

    /// Bus 120, car or taxi 104, shoe 96; the box bottom at y 260.
    private func mover(_ g: Geo, _ slot: KitSlot, x: CGFloat) -> some View {
        let size: CGFloat = switch slot {
        case .busDouble, .busSingle, .busMini, .busShuttle: 120
        case .shoe: 96
        default: 104
        }
        let side = g.len(size)
        return DrivingKitIcon(slot, size: side)
            .frame(width: side, height: side)
            .offset(x: g.x(x) - side / 2, y: g.y(Self.moverBottom) - side)
    }

    // MARK: Words on top

    /// Words sit at x × kx and y × k (the drawing's two scales), at their real type sizes.
    @ViewBuilder private func texts(kx: CGFloat, k: CGFloat) -> some View {
        switch look {
        case let .trip(trip):
            label(trip.homeLabel, x: Self.homeX, kx: kx, k: k)
            label(trip.destinationLabel, x: Self.destinationX, kx: kx, k: k)
            card(title: trip.cardTitle, caption: trip.cardCaption, owner: (trip.owner, trip.ownerName))
                .offset(x: (trip.showsStops ? 236 : 56) * kx, y: (trip.showsStops ? 38 : 30) * k)
        case let .live(live):
            label(live.ourStopLabel, x: Self.homeX, kx: kx, k: k)
            label(live.destinationLabel, x: Self.destinationX, kx: kx, k: k)
            // Legend at (946, 16): the white plate with the kid's 1st-choice bus number means "my bus"
            // (an empty plate read as broken on the iPad, 2026-11-09).
            HStack(spacing: Spacing.xs) {
                NumberPlate(live.myService.isEmpty ? " " : live.myService, isMine: true, small: true)
                Text(live.myBus).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink).fixedSize()
            }
            .offset(x: 946 * kx, y: 16 * k)
            ForEach(live.buses.filter(\.showsBubble)) { bus in
                let x = min(max(bus.x, 120), Self.size.width - 120)
                Color.clear.frame(width: 1, height: 1)
                    .overlay(alignment: .bottom) {
                        LiveBusBubble(service: bus.service, minutes: bus.minutes,
                                      kind: bus.isMine ? .mine(face: live.owner, name: live.ownerName, myBus: live.myBus)
                                          : .tooSoon(live.tooSoon))
                    }
                    .offset(x: x * kx, y: (Self.moverBottom - 120 - 8) * k)
                    .animation(.linear(duration: 1), value: bus.x)
            }
        case let .homeAllDay(title):
            card(title: title, caption: nil, owner: nil).offset(x: 120 * kx, y: 38 * k)
        }
    }

    /// Centred on its stop, top at y 274; a label that would cross x 1232 is right-aligned to it.
    private func label(_ text: String, x: CGFloat, kx: CGFloat, k: CGFloat) -> some View {
        let half = min(100, Self.rightEdge - x)
        return Color.clear.frame(width: 2 * half * kx, height: 1)
            .overlay(alignment: .topTrailing) {
                Text(text).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink)
                    .lineLimit(1).fixedSize()
                    .frame(minWidth: 2 * half * kx)
            }
            .offset(x: (x - half) * kx, y: Self.labelTop * k)
    }

    private func card(title: String, caption: String?, owner: (KidFace.Badge, String)?) -> some View {
        HStack(spacing: Spacing.s) {
            if let owner { KidFace(owner.0, name: owner.1, size: 40) }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let caption { Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText) }
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .crayonBackground(.roundedRect(cornerRadius: 18), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 21)
        .fixedSize()
    }
}

private extension MarkerStyle {
    func with(width: CGFloat) -> MarkerStyle { MarkerStyle(width: width, roughness: roughness, bowing: bowing) }
    /// How far `CrayonSurface` pulls a shape's line in from its frame (half the line width).
    var inset: CGFloat { width / 2 }
}
