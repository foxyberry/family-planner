import CrayonKit
import DesignSystem
import KitArt
import SnapshotTesting
import SwiftUI
import XCTest

/// One picture per design-system part, compared with the committed baselines in __Snapshots__.
/// Re-record with `make snapshots-record`, then compare the pictures with boards 0b and 0c.
@MainActor
final class ComponentSnapshotTests: XCTestCase {
    /// Row-sized parts on the 12.9-inch screen: eight columns in the two-kid view (the design
    /// width), twelve for one kid, and four as the narrowest supported width.
    /// Baselines are committed to a public repo, so they never show local private pictures.
    static let art = BundledKitArt(includePrivate: false)
    private static let grid = GridMetrics(width: 1366)
    private static let rowWidth = grid.span(8)
    private static let widths: [(name: String, width: CGFloat)] = [
        ("half", grid.span(4)), ("design", rowWidth), ("wide", grid.span(12)),
    ]

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertTrue(FontRegistrar.registerAll(), "Playpen Sans did not register")
    }

    // MARK: - 0b Controls

    func testInkButton() { snap(InkButton("Missions") {}) }

    /// Off: a Save with nothing to save yet, at 40 % (as S1–S4's Next and the mission card's Save).
    func testInkButtonDisabled() { snap(InkButton("Save", isEnabled: false) {}) }

    /// Spec "Night mapping": a night control (board A1n's Diary button).
    func testInkButtonNight() {
        snap(InkButton("Diary", arrow: true, look: .night) {}
            .frame(width: 384)
            .padding(Spacing.l)
            .background(CrayonColor.night))
    }


    func testRoundButtons() {
        snap(HStack(spacing: Spacing.m) {
            RoundButton(glyph: .chevronLeft) {}
            RoundButton(glyph: .plus) {}
        })
    }

    /// Board G0: the pencil, 56 in an 80 circle.
    func testPencilButton() {
        snap(HStack(spacing: Spacing.m) {
            RoundButton(picture: .pencil) {}
            // Night: the pencil on a night control round.
            RoundButton(picture: .pencil) {}.look(.night)
        }
        .padding(Spacing.m)
        .background(CrayonColor.night))
    }

    /// Board G1: Undo on, Redo off (the one off look, 40 %), 72 each.
    func testUndoRedoButtons() {
        snap(HStack(spacing: Spacing.s) {
            RoundButton(glyph: .undo) {}.size(72)
            RoundButton(glyph: .redo) {}.size(72).enabled(false)
        })
    }

    func testCheckMarks() {
        snap(HStack(spacing: Spacing.m) {
            CheckMark(isDone: true)
            CheckMark(isDone: false)
        })
    }

    func testCrayonTabs() {
        snap(CrayonTabs(selection: .constant(0), items: [
            (0, "Kid A", KidFace.Badge(face: "kidGirl", colorIndex: 0)), (1, "Kid B", KidFace.Badge(face: "kidBoy", colorIndex: 1)), (2, "Family", nil),
        ]))
        // Spec "Give-way" step 5: three 180 tabs in a 420 column wrap; none shrinks.
        snap(CrayonTabs(selection: .constant(0), items: [(0, "Once", nil), (1, "Weekly", nil), (2, "Monthly", nil)],
                        itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm), width: 420, named: "wraps")
    }

    /// K1's year tabs: the picked one on a neutral ground, not a kid's sky blue.
    func testCrayonTabsNeutral() {
        snap(CrayonTabs(selection: .constant(2026), items: [(2026, "2026", nil), (2027, "2027", nil)],
                        itemSize: CGSize(width: 150, height: 72), spacing: 12, neutral: true))
    }

    // MARK: - K1 School calendar

    /// Spec K1 "Marks" (layout v74): plain, Kid A off, Kid B off, both, three kids, a public holiday,
    /// a public holiday inside a break (red on a chip), today's pill, today on a day off; then the open
    /// month's and the key's sizes.
    func testCalendarCells() {
        for dark in [false, true] {
            snap(HStack(spacing: 8) {
                ForEach(Array(Self.cellMarks.enumerated()), id: \.offset) { _, mark in CalendarCell(mark, size: .card) }
                ForEach(Array(Self.cellMarks.suffix(4).enumerated()), id: \.offset) { _, mark in CalendarCell(mark, size: .open) }
                ForEach(Array(Self.cellMarks.suffix(4).enumerated()), id: \.offset) { _, mark in CalendarCell(mark, size: .legend) }
            }
            .padding(Spacing.s)
            .background(CrayonColor.card), named: dark ? "night" : nil, dark: dark)
        }
    }

    /// Board K1: a month card (November 2026: Deepavali 8–9, the year-end break from the 21st, today
    /// the 22nd); board K1o: the same month open.
    func testMonthCards() {
        for dark in [false, true] {
            snap(MonthCard(title: "November", weekdays: Self.letters, weeks: Self.november, size: .card),
                 named: dark ? "card-night" : "card", dark: dark)
        }
        snap(MonthCard(title: "November 2026", weekdays: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                       weeks: Self.november, size: .open), named: "open")
    }

    /// Board K1: the key, wrapping "Today" to a second line in the 856 legend column.
    func testCalendarLegend() {
        snap(CalendarLegend(items: Self.legend).frame(width: 856, alignment: .leading), width: 856 + 2 * Spacing.m)
    }

    static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    static let cellMarks: [CalendarCell.Mark] = [
        .init(number: "3"), .init(number: "4", kids: [0]), .init(number: "5", kids: [1]),
        .init(number: "6", kids: [0, 1]), .init(number: "7", kids: [0, 1, 2]), .init(number: "25", isHoliday: true),
        .init(number: "21", kids: [0], isHoliday: true), .init(number: "22", isToday: true),
        .init(number: "23", kids: [0, 1], isToday: true),
    ]

    static var november: [[CalendarCell.Mark?]] {
        let cells: [CalendarCell.Mark?] = (0..<42).map { index in
            let day = index - 5
            guard (1...30).contains(day) else { return nil }
            return CalendarCell.Mark(number: "\(day)", kids: day >= 21 ? (day >= 23 ? [0, 1] : [0]) : [],
                                     isHoliday: day == 8 || day == 9, isToday: day == 22)
        }
        return stride(from: 0, to: 42, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    static let legend: [CalendarLegend.Item] = [
        .init(face: KidFace.Badge(face: "kidGirl", colorIndex: 0), swatch: .init(number: "", kids: [0]), label: "Kid A off"),
        .init(face: KidFace.Badge(face: "kidBoy", colorIndex: 1), swatch: .init(number: "", kids: [1]), label: "Kid B off"),
        .init(swatch: .init(number: "", kids: [0, 1]), label: "Both off"),
        .init(swatch: .init(number: "25", isHoliday: true), label: "Public holiday"),
        .init(swatch: .init(number: "22", isToday: true), label: "Today"),
    ]

    /// S1–S4 parts: step dots, colour swatches (one picked), a placeholder time, a face not picked yet.
    func testSetupParts() {
        snap(HStack(spacing: Spacing.m) {
            StepDots(current: 2)
            HStack(spacing: Spacing.xs) {
                ForEach(0..<4, id: \.self) { index in
                    ColourSwatch(colorIndex: index, isPicked: index == 0) {}
                }
            }
            TimeField(label: "7:30 am", time: .constant(Date(timeIntervalSince1970: 0)), isPlaceholder: true)
            KidFace(.init(face: "", colorIndex: 2))
            LockMark(size: 56)
        })
        snap(CrayonTabs(selection: .constant(0), items: [(0, "School", nil), (1, "Preschool", nil), (2, "At home", nil)],
                        itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm), named: "goesTo")
    }

    func testChips() {
        snap(HStack(spacing: Spacing.s) {
            DayChip("M", isOn: .constant(true))
            DayChip("T", isOn: .constant(false))
            DateChip(weekday: "Mon", day: 9, isOn: true) {}
            DateChip(weekday: "Tue", day: 10, isOn: false) {}
        })
    }

    func testFields() {
        snap(HStack(spacing: Spacing.m) {
            CrayonField("Activity name", text: .constant("")).frame(width: 480)
            TimeField(label: "7:30 am", time: .constant(Date(timeIntervalSince1970: 7 * 3600 + 30 * 60)))
        })
    }

    /// Board G2 Runs: the start date and the end, as paper fields.
    func testRunsFields() {
        snap(HStack(spacing: Spacing.m) {
            DateField(label: "9 Nov", date: .constant(Date(timeIntervalSince1970: 0)))
            FieldButton("End of term") {}
        })
    }

    /// Board C3 "What": five slots and "More", closed and open (every picture, 6 per row).
    func testPictureRow() {
        let row = [KitSlot.actSwim, .actArt, .actMusic, .actPiano, .actDance]
        snap(PictureRow(slots: row, selection: .constant(.actSwim), all: row, isShowingAll: false,
                        moreTitle: "More") {}, width: Self.rowWidth, named: "closed")
        snap(PictureRow(slots: row, selection: .constant(.actSwim),
                        all: row + [.actFootball, .actStory, .actCCA, .actPlay, .homework, .doctor, .cake],
                        isShowingAll: true, moreTitle: "More") {}
            .frame(height: 440, alignment: .top), width: Self.rowWidth, named: "open")
        // Spec C3 "What" (N15): the country flags after the pictures, from a row of their own.
        snap(PictureRow(slots: row, selection: .constant(.flagKR),
                        all: row + [.actFootball, .actStory, .actCCA, .actPlay, .homework, .doctor, .cake],
                        flags: [.flagKR, .flagJP, .flagCN, .flagUK, .flagFR, .flagIN, .flagTH, .flagVN],
                        isShowingAll: true, moreTitle: "More") {}
            .frame(height: 640, alignment: .top), width: Self.rowWidth, named: "flags")
        // Spec G1f: in the 424 side card the slots wrap 4 per row, 24 apart; "More" is a 472 × 300
        // card 8 under the last row, 4 per row too, scrolling inside (two rows and a 44 peek).
        snap(PictureRow(slots: [.actPlay, .snack, .actStory, .homework, .tv, .actArt, .actMusic], selection: .constant(.actPlay),
                        all: [.actSleep, .pyjamas, .teddy, .sun, .toilet, .toothbrush, .washFace, .hairBrush, .shirt, .actBreakfast],
                        flags: [.flagKR, .flagJP], isShowingAll: true, moreTitle: "More", columns: 4) {}
            .frame(width: 424, height: 620, alignment: .top), width: 472, named: "narrow")
    }

    func testIconPicker() {
        snap(IconPicker(selection: .constant(.actSwim),
                        slots: [.actSwim, .actDance, .actArt, .actMusic, .actStory, .actCCA],
                        drawing: IconPicker.Drawing {}),
             width: Self.rowWidth)
    }

    /// Spec "Event form rows", Bring: every picked picture has the ring.
    func testIconPickerMultiPick() {
        snap(IconPicker(picked: [.backpack, .waterBottle], slots: [.backpack, .lunchBox, .waterBottle]) { _ in },
             width: Self.rowWidth)
    }

    func testTimeLeft() {
        snap(TimeLeft("19 min", isLate: false), named: "19")
        snap(TimeLeft("\u{2212}2 min", isLate: true), named: "minus2")
        snap(TimeLeft("1h 20m", isLate: false, compact: true), named: "compact")
    }

    /// Board A3r: a kid ready with no medal has the crown on the done knob, no check.
    func testSlideToGoDoneWithCrown() {
        snap(SlideToGo(state: .done, idleTitle: "Slide", doneTitle: "Ready!", knob: .star, doneKnob: .crown) {},
             width: Self.rowWidth)
    }

    func testSlideToGoStates() {
        let states: [(String, SlideToGoModel.Phase)] = [
            ("idle", .idle), ("dragging", .dragging(progress: 0.5)), ("done", .done),
        ]
        for (name, state) in states {
            snap(slide(state), width: Self.rowWidth, named: name)
        }
    }

    /// A new phase from the parent (undo: done → idle) replaces the slide's own.
    /// Compared with the idle picture of testSlideToGoStates.
    func testSlideToGoFollowsStateChanges() {
        snap(UnlockingSlider(), width: Self.rowWidth, named: "idle", testName: "testSlideToGoStates()")
    }

    private struct UnlockingSlider: View {
        @State private var phase = SlideToGoModel.Phase.done

        var body: some View {
            SlideToGo(state: phase, idleTitle: "Slide to go",
                      doneTitle: "On our way!") {}
                .onAppear { phase = .idle }
        }
    }

    func testSnapshotsUsePublicPicturesOnly() {
        XCTAssertFalse(Self.art.includePrivate)
    }

    func testSlideToGoWidths() {
        for (name, width) in Self.widths { snap(slide(.idle), width: width, named: name) }
    }

    /// Wrist-flick colouring (ST-13) on a filled card and a filled button.
    func testFlickFills() {
        snap(HStack(alignment: .top, spacing: Spacing.l) {
            Text("Swimming").crayonType(.title)
                .frame(width: 360, height: 200)
                .crayonBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.apricot, seed: 11)
            Text("Go!").crayonType(.head)
                .frame(width: 200, height: 96)
                .crayonBackground(.capsule, fill: CrayonStyle.blueCrayon, seed: 12)
        })
    }

    // MARK: - 0c Content

    /// A grown-up form row: the label fills the 104 … 232 column, the control starts on 232.
    func testFormLabel() {
        snap(VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) { FormLabel("Name"); Text("Swimming").crayonType(.body) }
            ListRow(leading: "Stop") { Text("00000") }
        }
        .environment(\.formLabelWidth, FormLines.labelColumn)
        .environment(\.cardPadding, Sizing.thirteenInch.cardPadding), width: Self.rowWidth)
    }

    func testPaperCardWidths() {
        for (name, width) in Self.widths {
            snap(PaperCard { Text("A sheet of paper").crayonType(.body) }, width: width, named: name)
        }
    }

    func testRows() {
        snap(VStack(spacing: Spacing.s) {
            ListRow(leading: "7:30") { Text("Bus to school") }
            TodayRow(leading: "Today") { Text("Swimming 15:30") }
        }, width: Self.rowWidth)
    }

    func testPickerPopover() {
        snap(PickerPopover(title: "Repeat", items: ["Once", "Every week"], selection: .constant("Every week"),
                           anchor: 0.3), width: 360)
    }

    func testLeagueProgress() {
        snap(LeagueProgress(level: .busSingle, levelName: "Single-Decker league", done: 18, goal: 30,
                            remaining: "12 more Go! days to the Double-Decker"), width: Self.rowWidth)
    }

    func testVoiceNote() { snap(VoiceNote(duration: .seconds(12), isPlaying: false) {}) }

    func testMedalsAndFaces() {
        snap(HStack(spacing: Spacing.m) {
            Medal(.gold, size: 104)
            Medal(.silver, size: 104)
            Medal(.bronze, size: 104)
            KidFace(.init(face: "kidGirl", colorIndex: 0))
            KidFace(.init(face: "kidBoy", colorIndex: 1), size: KidFace.medium)
            KidFace(.init(face: "kidGirl", colorIndex: 0), size: KidFace.small)
        })
    }

    // MARK: - M2

    private static let seedDay: [ClockSector] = [
        ClockSector(start: 0, end: 420, style: .sleep, iconName: "actSleep", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 420, end: 465, style: .morning, iconName: "actBreakfast", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 480, end: 900, style: .school, iconName: "actSchool", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 900, end: 930, style: .play, iconName: "actPlay", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 930, end: 990, style: .afterSchool, iconName: "actSwim", isCurrent: true, showsStar: false, priority: 1),
        ClockSector(start: 990, end: 1080, style: .play, iconName: "actPlay", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 1080, end: 1140, style: .dinner, iconName: "actDinner", isCurrent: false, showsStar: true, priority: 2),
        ClockSector(start: 1140, end: 1230, style: .evening, iconName: "actShower", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 1230, end: 1440, style: .sleep, iconName: "actSleep", isCurrent: false, showsStar: false, priority: 0),
    ]

    func testPieClockSeedDay() {
        snap(PieClock(sectors: Self.seedDay, now: 945, hub: .init(title: "Swimming", subtitle: "until 4:30 pm"))
            .padding(110))
    }

    /// Board A1 on a school day at 16:40: free time is plain paper between its edges, with no picture.
    func testPieClockFreeSlot() {
        let day: [ClockSector] = [
            ClockSector(start: 0, end: 390, style: .sleep, iconName: "actSleep", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 390, end: 450, style: .morning, iconName: "actBreakfast", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 450, end: 900, style: .school, iconName: "actSchool", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 900, end: 960, style: .play, iconName: "snack", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 960, end: 1020, style: .free, iconName: nil, isCurrent: true, showsStar: false, priority: 0),
            ClockSector(start: 1020, end: 1110, style: .play, iconName: "blocks", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 1110, end: 1155, style: .dinner, iconName: "actDinner", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 1155, end: 1200, style: .evening, iconName: "actShower", isCurrent: false, showsStar: false, priority: 0),
            ClockSector(start: 1200, end: 1440, style: .sleep, iconName: "actSleep", isCurrent: false, showsStar: false, priority: 0),
        ]
        snap(PieClock(sectors: day, now: 1000, hub: .init(title: "Free time", subtitle: "until 5:00 pm")).padding(110))
    }

    func testPieClockEmpty() {
        snap(PieClock(sectors: [], now: nil, hub: .init(title: "Nothing planned", subtitle: nil)).padding(110))
    }

    func testHubLongTitle() {
        snap(PieClock(sectors: Self.seedDay, now: 945,
                      hub: .init(title: "Swimming with the whole class", subtitle: "until 4:30 pm"), holdProgress: 0.6)
            .padding(110))
    }

    /// Board E3 at 9:15: "Weekend school" on two lines at head 36, "until" inside the hub.
    func testHubTwoLineTitle() {
        snap(PieClock(sectors: Self.seedDay, now: 555, hub: .init(title: "Weekend school",
                                                                  subtitle: "until 12:00 pm"))
            .padding(110))
    }

    func testHubLongSingleWord() {
        snap(PieClock(sectors: Self.seedDay, now: 945, hub: .init(title: "Supercalifragilistic", subtitle: "until 4:30 pm"))
            .padding(110))
    }

    /// Layout v68 "Next shape": Kid A's Next row and Kid B's Now and Next rows (126 apart on the
    /// boards); a just-once star; a long title ending with "…" inside the panel; no time line; the
    /// night plates (board A1n).
    /// Spec A1 "Next things" (layout v75): the time cell and dots, later rows, mission rows and the next
    /// card, by day and at night.
    func testNextThings() {
        let kidA = KidFace.Badge(face: "kidGirl", colorIndex: 0), kidB = KidFace.Badge(face: "kidBoy", colorIndex: 1)
        snap(VStack(alignment: .leading, spacing: 16) {
            // A1 (layout v75): later rows, a mission row, the next card, by day.
            NextThingRow(time: .soon(number: "35", unit: "min", dots: 4), picture: .actSwim, title: "Swimming",
                         faces: [kidA], hatch: nil, size: .row, faded: false, look: .day)
            NextThingRow(time: .at(time: "4:30", period: "pm"), picture: .actPlay, title: "Snack", faces: [kidA, kidB], hatch: nil,
                         size: .row, faded: false, look: .day)
            NextThingRow(time: .day(label: "Tomorrow", time: "7:25 am"), picture: .actSchool,
                         title: "School with a very long name", faces: [kidA], hatch: nil, size: .row, faded: false,
                         look: .day)
            NextThingRow(time: .soon(number: "50", unit: "min", dots: 5), picture: .actSwim, title: "Swimming",
                         faces: [kidA], hatch: .kid(0), size: .row, faded: false, look: .day)
            NextThingRow(time: .at(time: "4:00", period: "pm"), picture: .actPlay, title: "Play", faces: [kidB], hatch: nil, size: .row,
                         faded: true, look: .day)
            NextThingRow(time: .soon(number: "12", unit: "min", dots: 2), picture: .actSchool, title: "School",
                         faces: [kidA, kidB], hatch: .shared, size: .card, faded: false, look: .day)
        }.padding(.leading, 12), width: 480)
        snap(VStack(alignment: .leading, spacing: 16) {
            NextThingRow(time: .day(label: "Tomorrow", time: "7:25 am"), picture: .actSchool, title: "School",
                         faces: [kidA], hatch: nil, size: .row, faded: false, look: .night)
            NextThingRow(time: .at(time: "8:00", period: "pm"), picture: .actSleep, title: "Bed", faces: [kidA, kidB], hatch: nil,
                         size: .card, faded: false, look: .night)
            NextThingRow(time: .soon(number: "8", unit: "min", dots: 1), picture: .actSwim, title: "Swimming",
                         faces: [kidB], hatch: .kid(1), size: .row, faded: false, look: .night)
        }.padding(.leading, 12).padding(Spacing.s).background(CrayonColor.night), width: 480, named: "night")
    }

    /// Spec A1 "Time-left dots": none, some and all six red.
    func testTimeDots() {
        snap(VStack(alignment: .trailing, spacing: Spacing.s) {
            TimeDots(red: 0, breathes: false, look: .day)
            TimeDots(red: 3, breathes: false, look: .day)
            TimeDots(red: 6, breathes: false, look: .day)
        })
    }

    /// Spec A1 "Kid chips": two kids (Kid A picked), three kids, one kid with the name, and night.
    func testKidChips() {
        let kidA = KidFace.Badge(face: "kidGirl", colorIndex: 0), kidB = KidFace.Badge(face: "kidBoy", colorIndex: 1)
        let kidC = KidFace.Badge(face: "kidGirl", colorIndex: 2)
        snap(VStack(spacing: Spacing.m) {
            HStack(spacing: 12) {
                KidChip(face: kidA, picture: .actSchool, name: nil, isPicked: true, look: .day) {}
                KidChip(face: kidB, picture: .actPlay, name: nil, isPicked: false, look: .day) {}
            }
            HStack(spacing: 12) {
                KidChip(face: kidA, picture: .actSchool, name: nil, isPicked: false, look: .day) {}
                KidChip(face: kidB, picture: .actPlay, name: nil, isPicked: true, look: .day) {}
                KidChip(face: kidC, picture: .actPlay, name: nil, isPicked: false, look: .day) {}
            }
            KidChip(face: kidA, picture: .actSchool, name: "Kid A", isPicked: true, look: .day) {}
            HStack(spacing: 12) {
                KidChip(face: kidA, picture: .actSleep, name: nil, isPicked: true, look: .night) {}
                KidChip(face: kidB, picture: .actSleep, name: nil, isPicked: false, look: .night) {}
            }
            .padding(Spacing.s).background(CrayonColor.night)
        }, width: 456)
    }

    func testNextRow() {
        snap(VStack(alignment: .leading, spacing: 22) {
            NextRow(picture: .actPlay, caption: "Now", title: "Play", line: "until 4:00 pm")
            NextRow(picture: .cake, caption: "Next", title: "Birthday", line: "in 45 min", showsStar: true)
            NextRow(picture: .actSwim, caption: "Next", title: "Swimming with the whole class", line: "at 3:30 pm")
            NextRow(picture: .actPlay, caption: "Now", title: "Free time", line: nil)
            VStack(alignment: .leading, spacing: 22) {
                NextRow(picture: .actSleep, caption: "Now", title: "Sleep", line: "until 7:00 am", look: .night)
                NextRow(picture: .actBreakfast, caption: "Next", title: "Breakfast", line: "at 7:00 am", look: .night)
                // Board A1z / A1n: the next day's first thing.
                NextRow(picture: .actSchool, caption: "Tomorrow", title: "School", line: "leave 7:25 am", look: .night)
            }
            .padding(Spacing.s)
            .background(CrayonColor.night)
        })
    }

    /// Boards C3/C4: day preview rows, plain and the new item on its card.
    func testPreviewRows() {
        snap(VStack(spacing: Spacing.xs) {
            PreviewRow(time: "3:30 pm", isNew: false) { Text("Play").crayonType(.body) }
            PreviewRow(time: "4:00 pm", isNew: true) { Text("Swimming").crayonType(.head) }
        }, width: 382 + 2 * Spacing.m)
    }

    /// Boards C2/S3: bus pills, one on and one off.
    func testPillToggles() {
        snap(HStack(spacing: Spacing.sm) { PillToggle("12", isOn: true) {}; PillToggle("345", isOn: false) {} })
        // Spec "Several buses" (v61): a bus that changes, "12 · 34 → 33" with the arrow drawn, as wide
        // as its words + 80.
        snap(HStack(spacing: Spacing.sm) {
            PillToggle("12 · 34", isOn: true, then: "33") {}; PillToggle("97", isOn: false, then: "56") {}
        }, named: "changes")
    }

    /// Board C2 (v61): three plain pills, then the pill of a bus that changes wraps to the next line.
    func testPillToggleGridWraps() {
        snap(PillToggleGrid(controlWidth: 616) {
            PillToggle("12", isOn: true) {}
            PillToggle("34", isOn: true) {}
            PillToggle("56", isOn: false) {}
            PillToggle("12 · 34", isOn: true, then: "33") {}
        }, width: 616 + 2 * Spacing.m)
    }

    /// Boards C2 / S3: "+ A bus that changes…".
    func testPlusLink() { snap(PlusLink("A bus that changes…") {}) }

    /// Boards G2 / C2c: the side column's remove button, 472 × 88.
    func testRemoveButton() { snap(RemoveButton("Remove this bus") {}.frame(width: 472), width: 472 + 2 * Spacing.m) }

    /// Spec "Kid card" (board S1, two columns): Name with the face inside + Age, Colour + Face, rows
    /// 24 apart drawn on the form lines; made-up names only.
    func testKidCard() {
        let words = KidCard.Words(name: "Name", namePlaceholder: "Child's name", age: "Age", agePlaceholder: "Age",
                              colour: "Colour", face: "Face", colourCount: 4,
                              faces: [.kidGirl, .kidBoy])
        snap(PaperCard(padding: Sizing.thirteenInch.cardPadding) {
            KidCard(words: words, name: .constant("Kid A"), age: .constant("7"),
                    badge: KidFace.Badge(face: "kidGirl", colorIndex: 1), colorIndex: 1,
                    face: "kidGirl", onColour: { _ in }, onFace: { _ in })
                .formLines(KidCard.lines(GrownupLayout(sizing: Sizing(width: 1376, height: 1032)), words: words))
        }.frame(width: 800), width: 840)
    }

    /// Boards C2 / C2c / S3: − 72, the value in 144, + 72, the caption 16 after.
    func testMinutesStepper() {
        snap(MinutesStepper(value: "10 min", caption: "to the stop", minus: {}, plus: {}), width: 560)
    }

    /// S4 switch list: the switch on and off, the off look, and a row with a warning caption.
    func testSettingRows() {
        snap(HStack(spacing: Spacing.m) { CrayonSwitch(isOn: true); CrayonSwitch(isOn: false) }, named: "switches")
        // Off (G2b's Medal without a trip): the one off look, 40 %, off and on.
        snap(HStack(spacing: Spacing.m) {
            CrayonSwitch(isOn: false, isEnabled: false)
            CrayonSwitch(isOn: true, isEnabled: false)
        }, named: "switches-off")
        snap(VStack(spacing: 20) {
            SettingRow(title: "Grown-up lock", caption: "Face ID before grown-up screens", isOn: true, action: {}) {
                LockMark(size: 56)
            }
            SettingRow(title: "Grown-up lock",
                       caption: "Off: anyone who holds the clock for 2 s can change the plan.",
                       captionIsWarning: true, isOn: false, action: {}) { LockMark(size: 56) }
        }, width: 738 + 2 * Spacing.m, named: "rows")
        // Board S4 (layout v56): rows that hug their words, 24 apart, the words 24 after the picture.
        snap(VStack(alignment: .leading, spacing: Spacing.m) {
            SettingRow(title: "Grown-up lock", caption: "Face ID before grown-up screens", isOn: true, hugs: true,
                       action: {}) { LockMark(size: 56) }
            SettingRow(title: "Medals", caption: "Gold, Silver or Bronze for getting ready in time", isOn: false,
                       hugs: true, action: {}) { KitIcon(.medalGold, size: 56) }
        }.frame(width: 726), width: 726 + 2 * Spacing.m, named: "hugging")
    }

    /// Layout v14: rows 72 tall never overlap, a long name ends in "…" only at 610, and more rows
    /// than fit scroll inside the card.
    func testResultListCard() {
        let rows: [ResultListCard.Row] = (0..<3).map { index in
            .init(id: "\(index)", title: index == 0 ? "Opp Example Hotel With A Very Long Name Past The Card Edge"
                                                   : "Example Stop \(index)",
                  caption: "Example Rd · 0000\(index)") {}
        } + [.init(id: "more", glyph: .plus, title: "Not in the list? Type the name") {}]
        snap(ResultListCard(rows: rows, visibleRows: 6, seed: 55, width: 610), named: "fits")
        snap(ResultListCard(rows: rows, visibleRows: 2, seed: 55, width: 610), named: "scrolls")
        XCTAssertEqual(ResultListCard.height(rows: 8, visible: 6, sizing: .thirteenInch), 6 * 72 + 5 * 2 + 24)
    }

    func testConfirmCard() {
        snap(ConfirmCard(title: "Remove Swimming every week?",
                         message: "It leaves Kid A's clock from Mon 16 Nov. Days before stay in the diary.",
                         cancel: "Keep", confirm: "Remove", isDestructive: true, onCancel: {}, onConfirm: {}))
    }

    /// Spec "Layout balance" on board S1 v56: `FormRow` lines (second column on 590 / 656 … 808 (drawn 802) on the
    /// 13", the card hugging its rows) and `cardCorner`'s × with its confirm card hanging under it,
    /// on the 13" and the mini (the same picture × s).
    func testFormRowsAndCardCorner() {
        for (name, sizing) in [("13", Sizing(width: 1376, height: 1032)), ("mini", Sizing(width: 1133, height: 744))] {
            let layout = GrownupLayout(sizing: sizing)
            let lines = layout.formLines(secondLabels: ["Age", "Face"],
                                         secondControlWidth: 2 * sizing.pickedFace + sizing(Spacing.sm),
                                         firstControlMinimum: 4 * ColourSwatch.frame(sizing) + 3 * sizing(Spacing.sm))
            let card = PaperCard(seed: 61, padding: sizing.cardPadding) {
                VStack(alignment: .leading, spacing: sizing.formRowGap) {
                    FormRow("Name", kind: .field, second: "Age") {
                        CrayonField("Name", text: .constant("Kid A"))
                    } secondControl: {
                        CrayonField("Age", text: .constant("7"))
                    }
                    FormRow("Colour", kind: .choice, second: "Face") {
                        HStack(spacing: sizing(Spacing.sm)) {
                            ForEach(0..<4, id: \.self) { ColourSwatch(colorIndex: $0, isPicked: $0 == 0) {} }
                        }
                    } secondControl: {
                        HStack(spacing: sizing(Spacing.sm)) {
                            KitIcon(.kidGirl, size: sizing.pickedFace * 56 / 64).frame(width: sizing.pickedFace, height: sizing.pickedFace)
                            KitIcon(.kidBoy, size: sizing.pickedFace * 56 / 64).frame(width: sizing.pickedFace, height: sizing.pickedFace)
                        }
                        .partInset()
                    }
                }
                .formLines(lines)
            }
            .frame(width: layout.form.width, alignment: .topLeading)
            .cardCorner(size: sizing(Sizing.cornerControl)) {
                RoundButton(glyph: .close) {}.size(Sizing.cornerControl)
            } popover: {
                ConfirmCard(title: "Remove Kid A?", message: nil, cancel: "Keep", confirm: "Remove",
                            isDestructive: true, onCancel: {}, onConfirm: {})
            }
            .padding(.top, sizing(Spacing.l))
            .padding(.trailing, sizing(Spacing.l))
            .padding(.bottom, sizing(240))
            .withSizing(sizing)
            snap(card, named: name)
        }
    }

    /// Boards F1 and F3: a form card (title, choices, Done and Cancel) over the dim layer.
    func testFormCard() {
        snap(FormCard(title: "Ends", size: CGSize(width: 560, height: 420), done: "Done", cancel: "Cancel",
                      onDone: {}, onCancel: {}) {
            VStack(alignment: .leading, spacing: 0) {
                PickRow("End of this term", caption: "Fri 20 Nov", isPicked: true) {}
                PickRow("On a date", isPicked: false) {}
                PickRow("After … times", isPicked: false) {}
                PickRow("No end", isPicked: false) {}
            }
        }
        .frame(height: 480), width: 640)
        snap(FormCard(title: "From", size: CGSize(width: 640, height: 420), done: "Done", cancel: "Cancel",
                      onDone: {}, onCancel: {}) {
            ChoiceCircles([.init(id: "home", picture: .home, caption: "Home", isPicked: false),
                           .init(id: "school", picture: .wolfie, caption: "After School", isPicked: true),
                           .init(id: "more", picture: nil, caption: "", isPicked: false, word: "More")]) { _ in }
        }
        .frame(height: 480), width: 720, named: "from")
    }

    /// Board G5 (layout v69): the From when card with Date picked (its field) and the caption; the
    /// 232 middle tab picked with a long date (bold, round ends, no "…"); no middle tab (two tabs).
    func testFromWhenCard() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        snap(FromWhenCard(title: "Change from when?", tabs: [(0, "Today"), (1, "Tomorrow"), (2, "Date")],
                          selection: .constant(2), dateChoice: 2, dateLabel: "17 Nov", date: .constant(date),
                          caption: "17 Nov was changed and no longer fits. It'll be removed.",
                          save: "Save", cancel: "Cancel", onSave: {}, onCancel: {}), width: 700)
        snap(FromWhenCard(title: "Change from when?", tabs: [(0, "Today"), (1, "Wed 30 Nov"), (2, "Date")],
                          selection: .constant(1), dateChoice: 2, dateLabel: "30 Nov", date: .constant(date),
                          caption: nil, save: "Save", cancel: "Cancel", onSave: {}, onCancel: {}),
             width: 700, named: "middle")
        snap(FromWhenCard(title: "Change from when?", tabs: [(0, "Today"), (2, "Date")],
                          selection: .constant(0), dateChoice: 2, dateLabel: "30 Nov", date: .constant(date),
                          caption: nil, save: "Save", cancel: "Cancel", onSave: {}, onCancel: {}),
             width: 700, named: "noMiddle")
    }

    /// Board G1: the day button on today and on another day.
    func testDayButton() {
        snap(VStack(spacing: Spacing.m) {
            DayButton(today: "Today", date: "Tue 10 Nov") {}
            DayButton(today: nil, date: "Sat 14 Nov") {}
        }, width: 420)
    }

    /// Board G1c: the weekday header row, two weeks of number chips, today underlined, the picked
    /// day in sky.
    func testDayPickerCard() {
        snap(DayPickerCard(month: "November", weekdays: ComponentGallery.sampleWeekdays,
                           weeks: ComponentGallery.sampleWeeks,
                           today: "Today", onPage: { _ in }, onPick: { _ in }, onToday: {}), width: 660)
    }

    /// Board G1d: the shared ConfirmCard with its line's arrow drawn inline.
    func testConfirmCardGlyphTitle() {
        // Board C2c (v61): "Remove 12 · 34 → 33?", the arrow drawn in the title.
        snap(ConfirmCard(title: "Remove 12 · 34 %@ 33?", titleGlyph: .arrowRight, message: nil, cancel: "Keep",
                         confirm: "Remove", isDestructive: true, onCancel: {}, onConfirm: {}), width: 620)
    }

    func testConfirmCardGlyphLine() {
        snap(ConfirmCard(title: "Save the changes?", message: "Dinner 6:30 pm %@ 7:30 pm, this day",
                         messageGlyph: .arrowRight, cancel: "Cancel", confirm: "Save", isDestructive: false,
                         onCancel: {}, onConfirm: {}), width: 620)
    }

    func testLockOverlayStates() {
        // The English words of each state (AppFeature.State.lockCard picks them).
        let cards: [(String, String, String?, String)] = [
            ("scanning", "Look at the iPad to unlock.", nil, "Cancel"),
            ("notRecognised", "That didn't unlock.", "Try again", "Cancel"),
            ("notAvailable", "Face ID is off on this iPad, so anyone who holds the clock can come in. Turn it on in "
                + "Settings to keep these screens for grown-ups.", "Enter", "Cancel"),
            ("lockedOut", "Too many tries. Unlock the iPad with its passcode, then try again.", nil, "OK"),
        ]
        for (name, message, primary, cancel) in cards {
            snap(LockOverlay(title: "Grown-ups only", message: message, primary: primary, cancel: cancel,
                             onPrimary: {}, onCancel: {}).frame(width: 1000, height: 600), named: name)
        }
    }

    /// Board 0f: the shared grown-up header (Back, title, optional tabs, "Grown-ups only").
    func testGrownupHeader() {
        let width = Self.grid.span(12)
        snap(GrownupHeader(title: "Our kids", caption: "Grown-ups only", onBack: {}) {
            CrayonTabs(selection: .constant(0), items: [(0, "Kid A", KidFace.Badge(face: "kidGirl", colorIndex: 0)), (1, "Kid B", KidFace.Badge(face: "kidBoy", colorIndex: 1))])
        }, width: width, named: "tabs")
        snap(GrownupHeader(title: "Edit Swimming", caption: "Grown-ups only · behind the parent lock", onBack: {}),
             width: width, named: "caption")
        snap(GrownupHeader(title: "Edit Saturday language school and lunch with grandparents", caption: "Grown-ups only", onBack: {}),
             width: width, named: "longTitle")
    }

    // MARK: - Helpers

    private func slide(_ state: SlideToGoModel.Phase) -> SlideToGo {
        SlideToGo(state: state, idleTitle: "Slide to go",
                  doneTitle: "On our way!") {}
    }

    /// Lays the part on paper (fixed width when given, natural size otherwise) at 2x scale.
    /// The `.sizeThatFits` layout proposes a zero size, so heights (and widths when none is
    /// given) are fixed to the part's ideal size; otherwise text is squeezed or truncated.
    /// Time zone and locale are pinned so the simulator's settings never change a picture.
    /// Board A1n at 7:40 pm: lit paper face, chalk ticks and numbers on the night page.
    func testPieClockNight() {
        // The clock alone on the night page (KidFullScreen now lays out a whole board).
        snap(PieClock(sectors: Self.seedDay, now: 1180, hub: .init(title: "Shower", subtitle: "until 8:00 pm"),
                      look: .night)
            .padding(110)
            .frame(width: 964, height: 964)
            .background(KidLook.night.page))
    }

    func testSkySwitch() {
        snap(HStack(spacing: Spacing.l) {
            SkySwitch(look: .day, isAnimating: false) {}
            SkySwitch(look: .night, isAnimating: false) {}
        }
        .padding(Spacing.l)
        .background(CrayonColor.paper))
    }

    func testKitPlate() {
        snap(HStack(spacing: Spacing.l) {
            KitPlate(look: .day, size: 104) { KitIcon(.actDinner, size: 104) }
            KitPlate(look: .night, size: 104) { KitIcon(.actDinner, size: 104) }
            KitPlate(look: .night, size: 72) { KitIcon(.sun, size: 72) }
        }
        .padding(Spacing.l)
        .background(CrayonColor.night))
    }

    /// Board G1: Kid A's school day on the edit clock; Dinner selected, Play made free.
    private static let editDay: [ClockSector] = [
        ClockSector(start: 0, end: 390, style: .sleep, iconName: "actSleep", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 390, end: 450, style: .morning, iconName: "actBreakfast", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 450, end: 900, style: .school, iconName: "wolfie", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 900, end: 960, style: .play, iconName: "snack", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 960, end: 1110, style: .free, iconName: nil, isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 1110, end: 1155, style: .dinner, iconName: "actDinner", isCurrent: true, showsStar: false, priority: 0),
        ClockSector(start: 1155, end: 1200, style: .evening, iconName: "actShower", isCurrent: false, showsStar: false, priority: 0),
        ClockSector(start: 1200, end: 1440, style: .sleep, iconName: "actSleep", isCurrent: false, showsStar: false, priority: 0),
    ]

    private static let editKnobs: [EditClock.Knob] = [390, 450, 900, 960, 1110, 1155, 1200].map {
        EditClock.Knob(minute: $0, isLocked: $0 == 450 || $0 == 900)
    }

    /// Board G1: a "+" on every knob between two slices that are not free time; the dragged one hides it.
    private static func editAdds(except dragging: Int?) -> [EditClock.AddBetween] {
        [0, 1, 2, 5, 6].filter { $0 != dragging }.map { EditClock.AddBetween(knob: $0, minute: editKnobs[$0].minute) }
    }

    func testEditClock() {
        snap(EditClock(sectors: Self.editDay, knobs: Self.editKnobs, dragging: nil, dragOrigin: nil,
                       hub: .init(title: "Dinner"), onKnobDrag: { _, _ in }, onKnobEnd: { _ in },
                       onSliceTap: { _ in }, onPlusTap: { _ in }, addButtons: Self.editAdds(except: nil))
            .padding(80))
    }

    func testEditClockDragging() {
        snap(EditClock(sectors: Self.editDay, knobs: Self.editKnobs, dragging: 5, dragOrigin: 1140,
                       hub: .init(above: "Dinner ends", time: "7:15 pm", below: "Shower starts"),
                       onKnobDrag: { _, _ in }, onKnobEnd: { _ in }, onSliceTap: { _ in },
                       onPlusTap: { _ in }, addButtons: Self.editAdds(except: 5))
            .padding(80))
    }

    func testMarkerGlyphs() {
        snap(HStack(spacing: Spacing.m) {
            ForEach(MarkerGlyph.allCases, id: \.self) { MarkerIcon($0, size: 40) }
            MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
            MarkerIcon(.arrowRight, size: 32)
        })
    }

    /// Board 0c2 kid parts: progress rings, the chosen-kid band and mission circles.
    func testKidParts() {
        snap(VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                CrayonRing(progress: 0.5, colorIndex: 0)
                CrayonRing(progress: 1, colorIndex: 1)
                ZStack {
                    KidBand(colorIndex: 0)
                    KidFace(.init(face: "kidGirl", colorIndex: 0))
                }
                .frame(width: 340, height: 100)
            }
            HStack(spacing: Spacing.m) {
                MissionCircle(picture: .toothbrush, name: "Teeth", colorIndex: 0, isDone: true, isCurrent: false)
                MissionCircle(picture: .shirt, name: "Get dressed", colorIndex: 0, isDone: false, isCurrent: true)
                MissionCircle(picture: .babyBottle, name: "Milk", colorIndex: 1, isDone: false, isCurrent: false)
            }
            // Board A2m: folded done ones, "+n" to the next page, "‹" back.
            HStack(spacing: Spacing.m) {
                MissionCircle(.tick, name: "3 done", colorIndex: 0)
                MissionCircle(.text("+3"), name: "3 more", colorIndex: 0)
                MissionCircle(.glyph(.chevronLeft), name: "Back", colorIndex: 1)
            }
        })
    }

    /// C5 footer: a marker glyph inside a wrapping caption.
    func testGlyphText() {
        snap(GlyphText("Drag %@ to change the order. Tap a row to rename it or change its picture.",
                       glyph: .handle, color: CrayonColor.softText)
            .frame(width: 520, alignment: .leading))
    }

    /// Board A2-MVP: to school by bus (stops, "Our stop") and A2-MVP-w: weekend school by car ("Home").
    func testWayStrip() {
        snap(VStack(spacing: Spacing.m) {
            // A2t: 12 min to leave, the bus on the road before our stop.
            WayStrip(trip: .init(destination: .wolfie, destinationLabel: "School", homeLabel: "Our stop",
                                 showsStops: true, mover: .busDouble, moverX: WayStrip.liveX(minutes: 12),
                                 cardTitle: "School at 7:30 am", cardCaption: "by bus · timetable",
                                 owner: KidFace.Badge(face: "kidGirl", colorIndex: 0)))
                .frame(width: 1248, height: 340)
            // A2t-w: the car waits right of home; the long place name is right-aligned.
            WayStrip(trip: .init(destination: .actLanguageSchool, destinationLabel: "Weekend school", homeLabel: "Home",
                                 showsStops: false, mover: .car, moverX: 990, cardTitle: "Weekend school at 9:00 am",
                                 cardCaption: "by car", owner: KidFace.Badge(face: "kidGirl", colorIndex: 0)))
                .frame(width: 1248, height: 340)
            WayStrip(homeAllDay: "Home all day")
                .frame(width: 1248, height: 340)
        }, width: 1300)
    }

    /// Vehicles on their way, at rest: the rigged buses are their stacked runs and match KitIcon.
    func testDrivingKitIcons() {
        snap(HStack(spacing: Spacing.l) {
            DrivingKitIcon(.busDouble, size: 120)
            DrivingKitIcon(.busSingle, size: 120)
            DrivingKitIcon(.busShuttle, size: 120)
            DrivingKitIcon(.car, size: 104)
            DrivingKitIcon(.shoe, size: 96)
        }
        .padding(Spacing.m), width: 760)
    }

    /// Board A2: my bus 12 at 12 min with the big bubble; 34 at 15 (tag under the bus, the bubble is
    /// above it), 34 at 22 (tag above), 12 at 24 (tag under: the row above is taken); legend 12 +
    /// faded 34. Made-up numbers only.
    func testWayStripLive() {
        func bus(_ id: String, _ service: String, _ minutes: Int, mine: Bool = false) -> WayStrip.LiveBus {
            WayStrip.LiveBus(id: id, x: WayStrip.liveX(minutes: minutes), picture: .busDouble, service: service,
                             minutes: "\(minutes) min", isMine: mine,
                             tag: mine ? nil : .bus(number: service, then: nil, minutes: "\(minutes) min"))
        }
        let live = WayStrip.Live(
            buses: [bus("0", "12", 12, mine: true), bus("1", "34", 15), bus("2", "34", 22), bus("3", "12", 24)],
            destination: .wolfie, destinationLabel: "School", ourStopLabel: "Our stop",
            owner: KidFace.Badge(face: "kidGirl", colorIndex: 0), myBus: "my bus",
            myService: "12", others: [WayStrip.Plate("34")])
        snap(WayStrip(live: live).frame(width: 1248, height: 340), width: 1300)
        // v61: the legend lists a bus that changes by its first buses and the drawn arrow; wide plates
        // show as many as fit the legend's width, then "+{n}".
        var changes = live
        let plates = [WayStrip.Plate("34"), WayStrip.Plate("12 · 34", then: "33"), WayStrip.Plate("97", then: "56"),
                      WayStrip.Plate("7", then: "9")]
        let shown = WayStrip.legendCount(plates) { "+\($0)" }
        changes.others = Array(plates.prefix(shown))
        changes.moreOthers = "+\(plates.count - shown)"
        snap(WayStrip(live: changes).frame(width: 1248, height: 340), width: 1300, named: "changes")
    }

    /// Spec "A2 strip": the tags of the other buses: a plain bus and a bus that changes.
    func testLiveBusTags() {
        snap(HStack(spacing: Spacing.s) {
            LiveBusTag(.bus(number: "1", then: nil, minutes: "4 min"))
            LiveBusTag(.bus(number: "34", then: "33", minutes: "12 min"))
        }, width: 760)
    }

    /// Board C3g: the Going row with Car picked.
    func testChoiceCircles() {
        snap(ChoiceCircles([.init(id: "none", picture: nil, caption: "None", isPicked: false),
                            .init(id: "walk", picture: .shoe, caption: "Walk", isPicked: false),
                            .init(id: "bus", picture: .busDouble, caption: "Bus", isPicked: false),
                            .init(id: "car", picture: .car, caption: "Car", isPicked: true),
                            .init(id: "taxi", picture: .taxi, caption: "Taxi", isPicked: false)]) { _ in }, width: 640)
    }

    /// Board A3: the medal badge on a full ring, gold, silver and bronze (at rest).
    func testMedalBadges() {
        snap(HStack(spacing: Spacing.l) {
            ForEach(MedalKind.allCases, id: \.self) { kind in
                ZStack {
                    CrayonRing(progress: 1, colorIndex: 0)
                    KidFace(KidFace.Badge(face: "kidGirl", colorIndex: 0), size: 56)
                }
                .overlay(alignment: .topLeading) { MedalBadge(kind, ring: 76, dropsIn: false) }
            }
        }
        .transaction { $0.disablesAnimations = true }, width: 420)
    }

    /// Spec "Header right": the live status after "Leave in".
    func testStatusDots() {
        snap(HStack(spacing: Spacing.l) {
            StatusDot("On time", tone: .onTime)
            StatusDot("Leave now!", tone: .hurry)
            StatusDot("Ask a grown-up", tone: .quiet)
            StatusDot("On time", tone: .onTime, compact: true)
            NumberPlate("1", isMine: true, small: true)
        }, width: 1100)
    }

    func testClockKnobsAndPlus() {
        snap(HStack(spacing: Spacing.m) {
            ClockKnob(.idle)
            ClockKnob(.dragging)
            ClockKnob(.locked)
            // Spec G1 (#213): every clock "+" is a RoundButton 56, on paper as on a boundary.
            RoundButton(glyph: .plus) {}.size(56)
        })
    }

    /// Spec "Night mapping" (boards C3, G1, G6 night): grown-up parts in dark mode. Chrome turns
    /// night control with chalk lines, picture grounds moon paper with ink, on-states keep ink.
    func testGrownupPartsAtNight() {
        snap(VStack(alignment: .leading, spacing: Spacing.m) {
            GrownupHeader(title: "Add to the day", caption: "Grown-ups only", onBack: {})
            PaperCard(seed: 31) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    CrayonTabs(selection: .constant(0), items: [
                        (0, "Kid A", KidFace.Badge(face: "kidGirl", colorIndex: 0)),
                        (1, "Kid B", KidFace.Badge(face: "kidBoy", colorIndex: 1)), (2, "Both", nil),
                    ])
                    ChoiceCircles([.init(id: "a", picture: .actSwim, caption: "Swim", isPicked: true),
                                   .init(id: "b", picture: .wolfie, caption: "School", isPicked: false),
                                   .init(id: "m", picture: nil, caption: "", isPicked: false, word: "More")]) { _ in }
                    CrayonField("Name", text: .constant(""))
                    HStack(spacing: Spacing.m) {
                        FieldButton("3:30 pm") {}
                        DayChip("M", isOn: .constant(true))
                        DayChip("T", isOn: .constant(false))
                        CheckMark(isDone: true, size: 40)
                    }
                    ListRow(leading: "From", minHeight: 60) { Text("After School") }
                    Text("Give it a name").crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .chevronLeft) {}
                InkButton("Add to the clock") {}.frame(width: 382)
            }
        }, width: 900, dark: true)
    }

    /// Board G1c: the picker's square 68 × 68 number chips, today underlined, the picked day in sky.
    func testCompactDateChips() {
        snap(HStack(spacing: Spacing.xs) {
            DateChip(day: 9, isOn: false, isToday: true) {}
            DateChip(day: 14, isOn: true) {}
            DateChip(day: 15, isOn: false) {}
        })
    }

    func testKidFullScreen() {
        // The frame is the board frame (1376 s wide, the window's height) from its top-left corner;
        // this 720 × 540 window gives s 0.523.
        let sizing = Sizing(width: 720, height: 540, safeTop: 0)
        snap(KidFullScreen {
            Text("Home: the clock uses the whole screen").crayonType(.head).padding(sizing(Spacing.m))
        }
        .withSizing(sizing)
        .frame(width: 720, height: 540))
    }

    private func snap(_ view: some View, width: CGFloat? = nil, named name: String? = nil, dark: Bool = false,
                      file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        let framed = view
            .environment(\.crayonOutline, CrayonColor.outline)
            .padding(Spacing.m)
            .frame(width: width)
            .fixedSize(horizontal: width == nil, vertical: true)
            .background(CrayonColor.paper)
            .foregroundStyle(CrayonColor.ink)
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .environment(\.timeZone, TimeZone(identifier: "UTC")!)
            .environment(\.kitArt, Self.art)
            .environment(\.colorScheme, dark ? .dark : .light)
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 2),
                                                    UITraitCollection(userInterfaceStyle: dark ? .dark : .light)])
        let failure = verifySnapshot(
            of: framed,
            as: .image(layout: .sizeThatFits, traits: traits),
            named: name,
            record: SnapshotLocation.recordDirectory == nil ? .never : .all,
            snapshotDirectory: SnapshotLocation.directory,
            file: file, testName: testName, line: line
        )
        if let failure {
            let fileName = SnapshotLocation.fileName(testName: testName, name: name)
            XCTFail(SnapshotLocation.oneLine(failure: failure, fileName: fileName), file: file, line: line)
        }
    }
}

/// Where baselines live. Bazel hands them to the test as runfiles; recording writes them to
/// the source tree path given in SNAPSHOT_RECORD_DIR (set by `make snapshots-record`).
private enum SnapshotLocation {
    static let recordDirectory = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD_DIR"]

    static var directory: String {
        if let recordDirectory { return recordDirectory }
        let runfiles = ProcessInfo.processInfo.environment["TEST_SRCDIR"] ?? ""
        return runfiles + "/_main/ios/DesignSystem/SnapshotTests/__Snapshots__"
    }

    /// Where swift-snapshot-testing writes the newly taken picture of a failed snapshot.
    static var artifacts: String {
        ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] ?? NSTemporaryDirectory()
    }

    /// The library's file name: the test name with non-word runs as "-", then the name or 1.
    static func fileName(testName: String, name: String?) -> String {
        let base = testName.replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(base).\(name ?? "1").png"
    }

    /// A single log line for CI: the snapshot's name and how much of it changed. The library's
    /// own message carries file URLs from the runner and no percentage.
    static func oneLine(failure: String, fileName: String) -> String {
        if recordDirectory != nil { return "recorded \(fileName)" }
        let reference = UIImage(contentsOfFile: directory + "/" + fileName)
        let actual = UIImage(contentsOfFile: artifacts + "/ComponentSnapshotTests/" + fileName)
        guard let reference, let actual else {
            return "snapshot \(fileName): " + (failure.split(separator: "\n").first.map(String.init) ?? failure)
        }
        return "snapshot \(fileName): " + SnapshotDiff.summary(reference: reference, actual: actual)
    }
}
