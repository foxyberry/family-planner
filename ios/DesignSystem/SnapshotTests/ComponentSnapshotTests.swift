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


    func testRoundButtons() {
        snap(HStack(spacing: Spacing.m) {
            RoundButton(glyph: .chevronLeft, accessibilityLabel: "Back") {}
            RoundButton(glyph: .plus, accessibilityLabel: "Add") {}
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

    func testIconPicker() {
        snap(IconPicker(selection: .constant(.actSwim),
                        slots: [.actSwim, .actDance, .actArt, .actMusic, .actStory, .actCCA]) {},
             width: Self.rowWidth)
    }

    func testTimeLeft() {
        snap(TimeLeft(minutes: 19), named: "19")
        snap(TimeLeft(minutes: -2), named: "minus2")
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
                            nextName: "Double-Decker"), width: Self.rowWidth)
    }

    func testVoiceNote() { snap(VoiceNote(duration: .seconds(12), isPlaying: false) {}) }

    func testMedalsAndFaces() {
        snap(HStack(spacing: Spacing.m) {
            Medal(.gold, size: 104)
            Medal(.silver, size: 104)
            Medal(.bronze, size: 104)
            KidFace(.init(face: "kidGirl", colorIndex: 0), name: "Kid A")
            KidFace(.init(face: "kidBoy", colorIndex: 1), name: "Kid B", size: KidFace.medium)
            KidFace(.init(face: "kidGirl", colorIndex: 0), name: "Kid A", size: KidFace.small)
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

    func testKidNowNext() {
        snap(HStack(spacing: Spacing.xl) {
            KidNowNext(now: "teddy", next: "actPlay")
            KidNowNext(now: "actPlay", next: nil)
            KidNowNext(now: "actShower", next: "actSleep", look: .night)
                .padding(Spacing.s)
                .background(CrayonColor.night)
        })
    }

    func testConfirmCard() {
        snap(ConfirmCard(title: "Remove Swimming every week?",
                         message: "It leaves Kid A's clock from Mon 16 Nov. Days before stay in the diary.",
                         cancel: "Keep", confirm: "Remove", isDestructive: true, onCancel: {}, onConfirm: {}))
    }

    func testLockOverlayStates() {
        let states: [(String, LockOverlay.State)] = [
            ("scanning", .scanning), ("notRecognised", .notRecognised),
            ("notAvailable", .notAvailable(touchID: false)), ("lockedOut", .lockedOut),
        ]
        for (name, state) in states {
            snap(LockOverlay(state: state, onPrimary: {}, onCancel: {}).frame(width: 1000, height: 600), named: name)
        }
    }

    /// Board 0f: the shared grown-up header (Back, title, optional tabs, "Grown-ups only" or the countdown).
    func testGrownupHeader() {
        let width = Self.grid.span(12)
        snap(GrownupHeader(title: "Our kids", onBack: {}) {
            CrayonTabs(selection: .constant(0), items: [(0, "Kid A", KidFace.Badge(face: "kidGirl", colorIndex: 0)), (1, "Kid B", KidFace.Badge(face: "kidBoy", colorIndex: 1))])
        }, width: width, named: "tabs")
        snap(GrownupHeader(title: "Edit Swimming", caption: "Grown-ups only · behind the parent lock", onBack: {}),
             width: width, named: "caption")
        snap(GrownupHeader(title: "Edit Saturday language school and lunch with grandparents", onBack: {})
            .environment(\.relockCaption, "Locks in 0:12"), width: width, named: "countdownLongTitle")
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
            SkySwitch(look: .day, isAnimating: false, label: "Day. Tap for night.") {}
            SkySwitch(look: .night, isAnimating: false, label: "Night. Tap for day.") {}
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

    /// Board C6: Kid A's school day on the edit clock; Dinner selected, Play made free.
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
        EditClock.Knob(minute: $0, isLocked: $0 == 450 || $0 == 900, label: "")
    }

    func testEditClock() {
        snap(EditClock(sectors: Self.editDay, knobs: Self.editKnobs, dragging: nil, dragOrigin: nil,
                       hub: .init(title: "Dinner"), onKnobDrag: { _, _ in }, onKnobEnd: { _ in },
                       onLockedTap: { _ in }, onSliceTap: { _ in }, onPlusTap: { _ in }, onKnobAdjust: { _, _ in })
            .padding(80))
    }

    func testEditClockDragging() {
        snap(EditClock(sectors: Self.editDay, knobs: Self.editKnobs, dragging: 5, dragOrigin: 1140,
                       hub: .init(above: "Dinner ends", time: "7:15 pm", below: "Shower starts"),
                       onKnobDrag: { _, _ in }, onKnobEnd: { _ in }, onLockedTap: { _ in }, onSliceTap: { _ in },
                       onPlusTap: { _ in }, onKnobAdjust: { _, _ in })
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
                    KidFace(.init(face: "kidGirl", colorIndex: 0), name: "Kid A")
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
                                 owner: KidFace.Badge(face: "kidGirl", colorIndex: 0), ownerName: "Kid A"))
                .frame(width: 1248, height: 340)
            // A2t-w: the car waits right of home; the long place name is right-aligned.
            WayStrip(trip: .init(destination: .actLanguageSchool, destinationLabel: "Weekend school", homeLabel: "Home",
                                 showsStops: false, mover: .car, moverX: 990, cardTitle: "Weekend school at 9:00 am",
                                 cardCaption: "by car", owner: KidFace.Badge(face: "kidGirl", colorIndex: 0),
                                 ownerName: "Kid A"))
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

    /// Spec "A2 live look": bus 1 in 4 min (too soon, faded) and the kid's bus in 28 min; made-up
    /// numbers only.
    func testWayStripLive() {
        let live = WayStrip.Live(
            buses: [WayStrip.LiveBus(id: "0", x: WayStrip.liveX(minutes: 4), picture: .busSingle, service: "1",
                                     minutes: "4 min", isMine: false, isTooSoon: true, showsBubble: true),
                    WayStrip.LiveBus(id: "1", x: WayStrip.liveX(minutes: 28), picture: .busDouble, service: "1",
                                     minutes: "28 min", isMine: true, isTooSoon: false, showsBubble: true)],
            destination: .wolfie, destinationLabel: "School", ourStopLabel: "Our stop",
            owner: KidFace.Badge(face: "kidGirl", colorIndex: 0), ownerName: "Kid A", myBus: "my bus",
            tooSoon: "too soon")
        snap(WayStrip(live: live).frame(width: 1248, height: 340), width: 1300)
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
                    KidFace(KidFace.Badge(face: "kidGirl", colorIndex: 0), name: "Kid A", size: 56)
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
        }, width: 900)
    }

    func testClockKnobsAndPlus() {
        snap(HStack(spacing: Spacing.m) {
            ClockKnob(.idle)
            ClockKnob(.dragging)
            ClockKnob(.locked)
            PlusGlyph(size: 40)
        })
    }

    func testKidFullScreen() {
        // The frame fills the window the Sizing describes, from its top-left corner.
        snap(KidFullScreen {
            Text("Home: the clock uses the whole screen").crayonType(.head).padding(Spacing.m)
        }
        .environment(\.sizing, Sizing(width: 720, height: 160, safeTop: 0))
        .frame(width: 720, height: 160))
    }

    private func snap(_ view: some View, width: CGFloat? = nil, named name: String? = nil,
                      file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        let framed = view
            .padding(Spacing.m)
            .frame(width: width)
            .fixedSize(horizontal: width == nil, vertical: true)
            .background(CrayonColor.paper)
            .foregroundStyle(CrayonColor.ink)
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .environment(\.timeZone, TimeZone(identifier: "UTC")!)
            .environment(\.kitArt, Self.art)
        let failure = verifySnapshot(
            of: framed,
            as: .image(layout: .sizeThatFits, traits: UITraitCollection(displayScale: 2)),
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
