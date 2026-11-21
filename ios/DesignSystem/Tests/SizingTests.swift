import DesignSystem
import SwiftUI
import XCTest

/// Spec "Sizing: one scale, no floors": one scale from the app window, every size board × s, the
/// board frame centred, and the status bar band left empty.
@MainActor
final class SizingTests: XCTestCase {
    private let thirteen = Sizing(width: 1376, height: 1032)
    private let family = Sizing(width: 1366, height: 1024, safeTop: 32)
    private let air = Sizing(width: 1180, height: 820)
    private let mini = Sizing(width: 1133, height: 744)
    /// The iPhone Duo inner screen (spec "Supported screens and windows").
    private let duo = Sizing(width: 890, height: 626)

    /// Spec "Sizing → One scale": s = min(W / 1376, (H − safe.top) / 1008), from the app window, with
    /// no lower limit.
    func testScalePerWindow() {
        XCTAssertEqual(thirteen.s, 1)
        XCTAssertEqual(family.s, 0.984, accuracy: 0.001)
        XCTAssertEqual(Sizing(width: 1210, height: 834).s, 0.804, accuracy: 0.001)
        XCTAssertEqual(air.s, 0.790, accuracy: 0.001)
        XCTAssertEqual(mini.s, 0.714, accuracy: 0.001)
        XCTAssertEqual(duo.s, 0.597, accuracy: 0.001)
        XCTAssertEqual(Sizing(width: 600, height: 500).s, 0.4365, accuracy: 0.001, "a small window: smaller still")
        XCTAssertEqual(Sizing(width: 688, height: 1032).s, 0.5, "a narrow window: the width sets s")
    }

    /// The window sets the sizing; before it is known the 13" stands in.
    func testSizingComesFromTheWindow() {
        XCTAssertEqual(Sizing.forWindow(CGSize(width: 1133, height: 744), safeTop: 24), mini)
        XCTAssertEqual(Sizing.forWindow(CGSize(width: 700, height: 744), safeTop: 24).s, 700 / 1376,
                       "Split View: the whole board, smaller")
        XCTAssertEqual(Sizing.forWindow(.zero, safeTop: 24), .thirteenInch)
    }

    /// Spec "Sizing → Place": the board frame is 1376 s wide and centred; the rest is paper.
    func testTheBoardFrameIsCentred() {
        XCTAssertEqual(thirteen.width, 1376)
        XCTAssertEqual(thirteen.bleed, 0)
        XCTAssertEqual(mini.width, 1376 * mini.s, accuracy: 0.01)
        XCTAssertEqual(2 * mini.bleed + mini.width, 1133, accuracy: 0.01)
        XCTAssertEqual(mini.height, 744, "the frame keeps the window's height; the board sits on safe.top")
        XCTAssertEqual(Sizing(width: 688, height: 1032).bleed, 0, "a width-set scale leaves paper only below")
    }

    func testThirteenInchGivesTheBoardBack() {
        for type in CrayonType.allCases { XCTAssertEqual(thirteen.size(of: type), type.size) }
        for gap in [4, 8, 12, 16, 24, 32, 40, 64] as [CGFloat] { XCTAssertEqual(thirteen(gap), gap) }
        XCTAssertEqual(thirteen.y(48), 48)
        XCTAssertEqual(thirteen.y(968), 968)
        XCTAssertEqual(thirteen.x(1312), 1312)
        XCTAssertEqual(thirteen.rect(864, 872, 472, 96), CGRect(x: 864, y: 872, width: 472, height: 96))
    }

    /// No floors: type, gaps and positions are the board's × s on the mini and the Duo alike.
    func testEverySizeIsTheBoardTimesS() {
        for sizing in [family, air, mini, duo] {
            let s = sizing.s
            for type in CrayonType.allCases {
                XCTAssertEqual(sizing.size(of: type), type.size * s, accuracy: 0.001, "\(type)")
            }
            for gap in [4, 8, 12, 16, 24, 32, 40, 64] as [CGFloat] { XCTAssertEqual(sizing(gap), gap * s, accuracy: 0.001) }
            XCTAssertEqual(sizing.x(1336), 1336 * s, accuracy: 0.001)
            XCTAssertEqual(sizing.y(968), sizing.safeTop + 944 * s, accuracy: 0.001)
        }
        XCTAssertEqual(mini.size(of: .caption), 17.1, accuracy: 0.1, "caption 24 × s: fractional, no floor")
        XCTAssertEqual(duo.size(of: .caption), 14.3, accuracy: 0.1)
    }

    /// Kid full screens fill the board frame from the top of the glass; nothing but the page runs
    /// under the status bar band, on the largest and smallest windows.
    func testStatusBandStaysEmpty() throws {
        for sizing in [thirteen, family, air, mini, duo] {
            let view = KidFullScreen {
                Color.black.frame(width: 200, height: 2000).offset(y: sizing.y(36))
            }
            .withSizing(sizing)
            let rows = try inkRows(of: view, size: CGSize(width: sizing.width, height: sizing.height))
            XCTAssertTrue(rows.prefix(Int(Sizing.statusBand)).allSatisfy { !$0 }, "ink in the band at \(sizing.width)")
            let first = try XCTUnwrap(rows.firstIndex(of: true))
            XCTAssertEqual(CGFloat(first), sizing.y(36), accuracy: 1.5)
        }
    }

    /// Placed parts land where their rects say, even next to text placed by baseline from the right
    /// (that once shifted the whole screen right by the text's width).
    func testPlacedPartsStayPutBesideBaselineText() throws {
        let view = ZStack(alignment: .topLeading) {
            Color.black.place(CGRect(x: 100, y: 50, width: 20, height: 20))
            Text(verbatim: "Leave in 33 min").crayonType(.title).place(right: 480, baseline: 300)
            Text(verbatim: "Kid A").crayonType(.head).place(left: 300, baseline: 200)
        }
        .frame(width: 500, height: 400, alignment: .topLeading)
        .background(Color.white)
        let rows = try inkRows(of: view, size: CGSize(width: 500, height: 400))
        let columns = try inkColumns(of: view, size: CGSize(width: 500, height: 400), rows: 50..<70)
        XCTAssertEqual(rows.firstIndex(of: true), 50, "the box's top")
        XCTAssertEqual(columns.firstIndex(of: true), 100, "the box's left")
    }

    /// For each pixel column, whether it has a dark pixel inside `rows`.
    private func inkColumns(of view: some View, size: CGSize, rows: Range<Int>) throws -> [Bool] {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (0..<width).map { column in
            rows.contains { row in let i = (row * width + column) * 4; return pixels[i] < 60 && pixels[i + 3] > 200 }
        }
    }

    /// For each pixel row, whether it holds any dark pixel.
    private func inkRows(of view: some View, size: CGSize) throws -> [Bool] {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // A bitmap context keeps the image's top row first in memory.
        return (0..<height).map { row in
            let offset = row * width * 4
            return stride(from: offset, to: offset + width * 4, by: 4).contains { pixels[$0] < 60 && pixels[$0 + 3] > 200 }
        }
    }
}
