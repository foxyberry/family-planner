import DesignSystem
import XCTest

/// Spec "A2 strip, when labels collide" with board A2's v57 buses (made-up numbers).
@MainActor
final class LiveTagLayoutTests: XCTestCase {
    private func tags(kx: CGFloat) -> [LiveTagLayout.Tag] {
        [(15, "34"), (22, "34"), (24, "12")].map { minutes, number in
            LiveTagLayout.Tag(centreX: WayStrip.liveX(minutes: minutes) * kx,
                              width: LiveBusTag.width(.bus(number: number, then: nil, minutes: "\(minutes) min")))
        }
    }

    private func bubble(kx: CGFloat, k: CGFloat) -> CGRect {
        // My bus at 12 min: x 540, the bubble's foot 8 above the bus top (132).
        CGRect(x: 540 * kx - LiveBusBubble.size.width / 2, y: 132 * k - LiveBusBubble.size.height,
               width: LiveBusBubble.size.width, height: LiveBusBubble.size.height)
    }

    private func frames(_ slots: [LiveTagLayout.Slot]) -> [CGRect] {
        slots.compactMap { slot -> CGRect? in if case let .shown(_, frame) = slot { frame } else { nil } }
    }

    func testTheBoardsRows() {
        let slots = LiveTagLayout.place(tags(kx: 1), kx: 1, k: 1, bubble: bubble(kx: 1, k: 1))
        let rows = slots.map { slot -> Int? in if case let .shown(row, _) = slot { row } else { nil } }
        XCTAssertEqual(rows, [1, 0, 1], "34 at 15 under (the bubble is above), 34 at 22 above, 12 at 24 under")
        let placed = frames(slots)
        XCTAssertEqual(placed[1].minY, 88, "the row above ends 8 above the bus top (140)")
        XCTAssertEqual(placed[0].minY, 268, "the row under starts 8 under the bus box")
        XCTAssertEqual(placed[1].width, 154, accuracy: 8, "about 151–158 wide")
    }

    /// The 11": real tag widths on a smaller strip still never overlap and stay inside it.
    func testElevenInchKeepsTagsApartAndInside() {
        let k: CGFloat = 820.0 / 1032.0, kx = (1180 - 128 * k) / 1248
        let placed = frames(LiveTagLayout.place(tags(kx: kx), kx: kx, k: k, bubble: bubble(kx: kx, k: k)))
        XCTAssertEqual(placed.count, 3)
        for (i, a) in placed.enumerated() {
            XCTAssertGreaterThanOrEqual(a.minY, 0)
            XCTAssertLessThanOrEqual(a.maxY, 340 * k)
            XCTAssertGreaterThanOrEqual(a.minX, 8 * kx - 0.01)
            XCTAssertFalse(a.intersects(bubble(kx: kx, k: k)))
            for b in placed[(i + 1)...] { XCTAssertFalse(a.intersects(b)) }
        }
    }

    /// One row above and one under (user, 2026-11-19): with both taken a tag is left out, never
    /// merged into a listing.
    func testATagWithNoFreeRowIsLeftOut() {
        let crowd = (0..<3).map { LiveTagLayout.Tag(centreX: 300 + CGFloat($0) * 4, width: 150) }
        let slots = LiveTagLayout.place(crowd, kx: 1, k: 1, bubble: nil)
        XCTAssertEqual(slots[2], .hidden)
    }

    /// v61: the legend shows up to 3 faded plates, fewer when wide plates of buses that change would
    /// run past the strip, and the "+{n}" for the rest always fits.
    func testTheLegendShowsThePlatesThatFit() {
        XCTAssertTrue(FontRegistrar.registerAll())
        let more: (Int) -> String = { "+\($0)" }
        let short = ["1", "2", "3", "4"].map { WayStrip.Plate($0) }
        XCTAssertEqual(WayStrip.legendCount(short, more: more), 3)
        XCTAssertEqual(WayStrip.legendCount(Array(short.prefix(2)), more: more), 2)
        let wide = [WayStrip.Plate("34"), WayStrip.Plate("12 · 34", then: "33"), WayStrip.Plate("97", then: "56")]
        let shown = WayStrip.legendCount(wide, more: more)
        XCTAssertEqual(shown, 2)
        let width = wide.prefix(shown).map { LiveBusTag.plateWidth($0.number, then: $0.then) }.reduce(0, +)
        XCTAssertLessThanOrEqual(width, WayStrip.legendWidth)
    }
}
