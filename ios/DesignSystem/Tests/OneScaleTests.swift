import DesignSystem
import SwiftUI
import XCTest

/// Spec "Sizing: one scale, no floors": every part is its board size × s. At s = 1 each named size
/// is the board's; on a small window (the mini, the iPhone Duo inner screen) each is the board's ×
/// the same s. The drawing test is the net for sizes written straight into a part: it draws parts
/// at s = 1 and on the Duo and checks the drawn box shrinks by s.
@MainActor
final class OneScaleTests: XCTestCase {
    private let thirteen = Sizing.thirteenInch
    private let mini = Sizing(width: 1133, height: 744)
    private let duo = Sizing(width: 890, height: 626)

    /// Each named part size with its board value.
    private func partSizes(_ sizing: Sizing) -> [(String, CGFloat, CGFloat)] {
        [("field", sizing.fieldHeight, 80), ("time field", sizing.timeFieldWidth, 176),
         ("tab", sizing.tabHeight(), 72), ("tab 64", sizing.tabHeight(64), 64),
         ("stepper value", sizing.stepperValueWidth, 144),
         ("switch w", sizing.switchSize.width, 96), ("switch h", sizing.switchSize.height, 52),
         ("knob", sizing.switchKnob, 44), ("setting row", sizing.settingRowHeight, 120),
         ("setting picture", sizing.settingRowPicture, 56), ("swatch", sizing.swatch, 56),
         ("face", sizing.pickedFace, 64), ("date chip w", sizing.dateChip.width, 96),
         ("date chip h", sizing.dateChip.height, 104), ("clock plus", sizing.clockPlus, 56),
         ("one-line row", sizing.oneLineRow, 48), ("two-line row", sizing.twoLineRow, 72),
         ("text padding", sizing.textPadding, 24), ("small card", sizing.smallCardInset, 24),
         ("pair gap", sizing.pairGap, 16), ("joiner", sizing.joiner, 40), ("mission", sizing.missionCircle, 112),
         ("kid corner", sizing.kidCornerControl, 96), ("time left", sizing.timeLeftCompact, 72),
         ("inset", sizing.inset, 6), ("pick ring", sizing.pickRing, 4), ("row gap", sizing.formRowGap, 24),
         ("card gap", sizing.cardGap, 28), ("caption gap", sizing.captionGap, 2),
         ("card padding", sizing.cardPadding.leading, 38), ("card padding right", sizing.cardPadding.trailing, 32),
         ("stepper row", MinutesStepper.rowHeight(sizing), 72), ("swatch frame", ColourSwatch.frame(sizing), 68),
         ("choice row", sizing.choiceRowHeight, 76)]
    }

    func testThirteenInchIsTheBoard() {
        for (name, value, board) in partSizes(thirteen) { XCTAssertEqual(value, board, name) }
    }

    /// No floors on the smallest windows: under 44 on the Duo is accepted (user, 2026-11-21).
    func testSmallWindowsScaleEveryPartBySameS() {
        for sizing in [mini, duo] {
            for (name, value, board) in partSizes(sizing) {
                XCTAssertEqual(value, board * sizing.s, accuracy: 0.001, "\(name) at s \(sizing.s)")
            }
        }
        XCTAssertLessThan(duo(Sizing.cornerControl), 44, "the S1 remove × on the Duo, about 29")
    }

    /// Layout v61: plain bus pills are 180; the pill of a bus that changes is its words + 80 (board C2
    /// "12 · 34 → 33" 280 on the 13"), measured on the board, so it is the same picture at every s.
    func testABusThatChangesPillIsItsWordsPlus80() {
        XCTAssertTrue(FontRegistrar.registerAll())
        XCTAssertEqual(PillToggle.width("12", then: nil, sizing: thirteen), 180)
        XCTAssertEqual(PillToggle.width("12 · 34", then: "33", sizing: thirteen), 280, accuracy: 24)
        XCTAssertGreaterThan(PillToggle.width("12 · 34", then: "33", sizing: thirteen),
                             PillToggle.width("12", then: "33", sizing: thirteen))
        for sizing in [mini, duo] {
            XCTAssertEqual(PillToggle.width("12 · 34", then: "33", sizing: sizing),
                           PillToggle.width("12 · 34", then: "33", sizing: thirteen) * sizing.s, accuracy: 0.01)
        }
    }

    /// Text measured on the board: the same breaks at every s.
    func testTextWidthsScaleWithS() {
        XCTAssertTrue(FontRegistrar.registerAll())
        let board = CrayonType.body.width("Monthly", sizing: thirteen, bold: true)
        XCTAssertEqual(CrayonType.body.width("Monthly", sizing: duo, bold: true), board * duo.s, accuracy: 0.01)
        XCTAssertEqual(ConfirmCard.width(sizing: mini, cancel: "Keep editing"),
                       ConfirmCard.width(sizing: thirteen, cancel: "Keep editing") * mini.s, accuracy: 0.01)
    }

    /// The net: each part drawn on the Duo is its 13" drawing × s (±2 pt for the crayon line's
    /// pixel rounding). A size written into a part without × s fails here.
    func testPartsDrawnOnTheDuoAreTheBoardTimesS() throws {
        XCTAssertTrue(FontRegistrar.registerAll())
        let big = parts(thirteen), small = parts(duo)
        for ((name, bigPart), (_, smallPart)) in zip(big, small) {
            let bigBox = try inkBox(bigPart, sizing: thirteen)
            let smallBox = try inkBox(smallPart, sizing: duo)
            XCTAssertEqual(smallBox.width, bigBox.width * duo.s, accuracy: 2, "\(name) width")
            XCTAssertEqual(smallBox.height, bigBox.height * duo.s, accuracy: 2, "\(name) height")
        }
    }

    /// The parts, with any frame a layout would give them (board × s).
    private func parts(_ sizing: Sizing) -> [(String, AnyView)] {
        [
            ("InkButton", AnyView(InkButton("Save") {}.frame(width: sizing(472)))),
            ("RoundButton", AnyView(RoundButton(glyph: .chevronLeft) {})),
            ("RoundButton 48", AnyView(RoundButton(glyph: .close) {}.size(48))),
            ("CheckMark", AnyView(CheckMark(isDone: true))),
            ("DayChip", AnyView(DayChip("M", isOn: .constant(true)))),
            ("DateChip", AnyView(DateChip(weekday: "Mon", day: 9, isOn: true) {})),
            ("PillToggle", AnyView(PillToggle("12", isOn: true) {})),
            ("CrayonTabs", AnyView(CrayonTabs(selection: .constant(1), items: [(1, "Once", nil), (2, "Weekly", nil)],
                                              itemSize: CGSize(width: 180, height: 72)))),
            ("CrayonSwitch", AnyView(CrayonSwitch(isOn: true))),
            ("ColourSwatch", AnyView(ColourSwatch(colorIndex: 0, isPicked: true) {})),
            ("MissionCircle", AnyView(MissionCircle(.tick, name: "Teeth", colorIndex: 0))),
            ("StepDots", AnyView(StepDots(current: 2))),
            ("PlusLink", AnyView(PlusLink("A bus that changes") {})),
            ("RemoveButton", AnyView(RemoveButton("Remove this bus") {}.frame(width: sizing(472)))),
            ("StatusDot", AnyView(StatusDot("On time", tone: .onTime))),
            ("caption", AnyView(Text(verbatim: "Example Primary School").crayonType(.caption))),
            ("ListRow", AnyView(ListRow(leading: "Stop") { Text(verbatim: "00000") }.frame(width: sizing(600)))),
            ("SettingRow", AnyView(SettingRow(title: "Grown-up lock", caption: "Face ID first", isOn: true,
                                              action: {}) { LockMark() }.frame(width: sizing(600)))),
            ("ConfirmCard", AnyView(ConfirmCard(title: "Remove Swimming?", message: nil, cancel: "Keep",
                                                confirm: "Remove", isDestructive: true, onCancel: {}, onConfirm: {}))),
            ("CrayonField", AnyView(CrayonField("Name", text: .constant("Kid A")).frame(width: sizing(400)))),
            ("TimeField", AnyView(TimeField(label: "7:30 am", time: .constant(.distantPast), width: sizing.timeFieldWidth))),
            ("ChoiceCircles", AnyView(ChoiceCircles([.init(id: "a", picture: nil, caption: "None", isPicked: true),
                                                     .init(id: "b", picture: nil, caption: "More", isPicked: false)]) { _ in })),
            ("LiveBusTag", AnyView(LiveBusTag(.bus(number: "34", then: nil, minutes: "15 min")))),
            ("ResultListCard", AnyView(ResultListCard(rows: [.init(id: "1", title: "Example Rd", caption: "00000") {}],
                                                      visibleRows: 3, seed: 55, width: sizing(610)))),
            ("PreviewRow", AnyView(PreviewRow(time: "10:00 am", isNew: true) { Text(verbatim: "Swimming") }
                .frame(width: sizing(472)))),
        ]
    }

    /// Spec "Sizing → Text that does not fit": a long typed name in a fixed-width tab ends with "…"
    /// inside its capsule; it never draws past the tab.
    func testALongNameStaysInsideItsTab() throws {
        XCTAssertTrue(FontRegistrar.registerAll())
        let tab = CrayonTabs(selection: .constant(1), items: [(1, "Kid with a very long name", KidFace.Badge(face: "", colorIndex: 0))],
                             itemSize: CGSize(width: 180, height: 72))
        let box = try inkBox(tab, sizing: thirteen)
        XCTAssertLessThanOrEqual(box.width, 180 + 4, "the label stays inside the 180 tab")
    }

    /// The box around everything drawn (alpha over 30 %), in points, on a clear 900 × 400 canvas.
    private func inkBox(_ view: some View, sizing: Sizing) throws -> CGRect {
        let size = CGSize(width: 900, height: 400)
        let content = view.fixedSize().withSizing(sizing)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 77 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        XCTAssertGreaterThanOrEqual(maxX, 0, "nothing drawn")
        return CGRect(x: CGFloat(minX) / 2, y: CGFloat(minY) / 2, width: CGFloat(maxX - minX + 1) / 2,
                      height: CGFloat(maxY - minY + 1) / 2)
    }
}
