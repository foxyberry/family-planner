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

    func testInkButton() { snap(InkButton("Missions →") {}) }

    func testKidPillButton() { snap(KidPillButton("Swimming", icon: .actSwim) {}) }

    func testRoundButtons() {
        snap(HStack(spacing: Spacing.m) {
            RoundButton(systemImage: "chevron.left", accessibilityLabel: "Back") {}
            RoundButton(text: "+", accessibilityLabel: "Add") {}
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
            (0, "Kid A", CrayonColor.kidABlue), (1, "Kid B", CrayonColor.kidBOrange), (2, "Family", nil),
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
            TimeField(time: .constant(Date(timeIntervalSince1970: 7 * 3600 + 30 * 60)))
        })
    }

    func testIconPicker() {
        snap(IconPicker(selection: .constant(.actSwim),
                        slots: [.actSwim, .actDance, .actArt, .actMusic, .actStory, .actCCA]) {})
    }

    func testTimeLeft() {
        snap(TimeLeft(minutes: 19), named: "19")
        snap(TimeLeft(minutes: -2), named: "minus2")
    }

    func testSlideToGoStates() {
        let states: [(String, SlideToGoModel.Phase)] = [
            ("locked", .locked(remaining: 3)), ("idle", .idle), ("dragging", .dragging(progress: 0.5)), ("done", .done),
        ]
        for (name, state) in states {
            snap(slide(state), width: Self.rowWidth, named: name)
        }
    }

    /// The parent unlocks the slider when the morning steps are done; it must not stay locked.
    /// Compared with the idle picture of testSlideToGoStates.
    func testSlideToGoFollowsStateChanges() {
        snap(UnlockingSlider(), width: Self.rowWidth, named: "idle", testName: "testSlideToGoStates()")
    }

    private struct UnlockingSlider: View {
        @State private var phase = SlideToGoModel.Phase.locked(remaining: 1)

        var body: some View {
            SlideToGo(state: phase, lockedTitle: "3 more, then slide", idleTitle: "Slide to go",
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

    // MARK: - 0c Content

    func testNowRowWidths() {
        for (name, width) in Self.widths {
            snap(NowRow(title: "Brush teeth", icon: .toothbrush, isDone: false) {}, width: width, named: name)
        }
    }

    func testNowRowLongTitleWrapsThenEllipsizes() {
        for (name, width) in Self.widths where name != "wide" {
            snap(NowRow(title: "Put on shoes and socks, then find your hat", icon: .shoe, isDone: false) {},
                 width: width, named: name)
        }
    }

    func testSlideToGoLockedNarrow() {
        snap(slide(.locked(remaining: 3)), width: Self.grid.span(4))
    }

    func testNowRowDone() {
        snap(NowRow(title: "Brush teeth", icon: .toothbrush, isDone: true) {}, width: Self.rowWidth)
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

    func testBusBubbles() {
        snap(HStack(alignment: .bottom, spacing: Spacing.l) {
            BusBubble(route: "123", minutes: 4, crowd: .seats, isMine: true, transferTo: nil)
            BusBubble(route: "45", minutes: 9, crowd: .standing, isMine: false, transferTo: "67")
            BusBubble(route: "123", minutes: 19, crowd: .full, isMine: true, transferTo: nil)
        })
    }

    func testLeagueProgress() {
        snap(LeagueProgress(level: .busSingle, levelName: "Single-Decker league", done: 18, goal: 30,
                            nextName: "Double-Decker"), width: Self.rowWidth)
    }

    func testVoiceNote() { snap(VoiceNote(duration: .seconds(12), isPlaying: false) {}) }

    func testMedalsAndDots() {
        snap(HStack(spacing: Spacing.m) {
            Medal(.gold, size: 104)
            Medal(.silver, size: 104)
            Medal(.bronze, size: 104)
            KidDot(color: CrayonColor.kidABlue)
            KidDot(color: CrayonColor.kidBOrange, size: 28)
        })
    }

    // MARK: - Helpers

    private func slide(_ state: SlideToGoModel.Phase) -> SlideToGo {
        SlideToGo(state: state, lockedTitle: "3 more, then slide", idleTitle: "Slide to go",
                  doneTitle: "On our way!") {}
    }

    /// Lays the part on paper (fixed width when given, natural size otherwise) at 2x scale.
    /// The `.sizeThatFits` layout proposes a zero size, so heights (and widths when none is
    /// given) are fixed to the part's ideal size; otherwise text is squeezed or truncated.
    /// Time zone and locale are pinned so the simulator's settings never change a picture.
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
