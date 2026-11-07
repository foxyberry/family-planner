import CrayonKit
import KitArt
import SwiftUI

/// Every design-system part on one screen, grouped like the design boards (0b controls,
/// 0c content, 0f frames). New parts are added here first. Reached from parent mode in debug builds.
public struct ComponentGallery: View {
    @State private var tab = 0
    @State private var monday = true
    @State private var tuesday = false
    @State private var name = ""
    @State private var time = Date(timeIntervalSince1970: 7 * 3600 + 30 * 60)
    @State private var picture: KitSlot? = .actSwim
    @State private var choice = "Every week"

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                section("0b · Controls") {
                    InkButton("Missions") {}
                    HStack(spacing: Spacing.m) {
                        KidPillButton("Swimming", icon: .actSwim) {}
                        RoundButton(systemImage: "chevron.left", accessibilityLabel: "Back") {}
                        RoundButton(text: "+", accessibilityLabel: "Add") {}
                        CheckMark(isDone: true)
                        CheckMark(isDone: false)
                    }
                    CrayonTabs(selection: $tab, items: [(0, "Kid A", CrayonColor.kidABlue), (1, "Kid B", CrayonColor.kidBOrange), (2, "Family", nil)])
                    HStack(spacing: Spacing.s) {
                        DayChip("M", isOn: $monday)
                        DayChip("T", isOn: $tuesday)
                        DateChip(weekday: "Mon", day: 9, isOn: true) {}
                        DateChip(weekday: "Tue", day: 10, isOn: false) {}
                    }
                    HStack(spacing: Spacing.m) {
                        CrayonField("Activity name", text: $name).frame(width: 480)
                        TimeField(time: $time)
                    }
                    IconPicker(selection: $picture, slots: [.actSwim, .actDance, .actArt, .actMusic, .actStory, .actCCA]) {}
                    HStack(spacing: Spacing.xl) {
                        TimeLeft(minutes: 19)
                        TimeLeft(minutes: -2)
                    }
                    SlideToGo(state: .locked(remaining: 3), lockedTitle: "3 more, then slide",
                              idleTitle: "Slide to go", doneTitle: "On our way!") {}
                    SlideToGo(state: .idle, lockedTitle: "", idleTitle: "Slide to go", doneTitle: "On our way!") {}
                    SlideToGo(state: .done, lockedTitle: "", idleTitle: "", doneTitle: "On our way!") {}
                }
                section("0c · Content") {
                    NowRow(title: "Brush teeth", icon: .toothbrush, isDone: false) {}
                    ListRow(leading: "7:30") { Text("Bus to school") }
                    TodayRow(leading: "Today") { Text("Swimming 15:30") }
                    PaperCard { Text("A sheet of paper").crayonType(.body) }
                    PickerPopover(title: "Repeat", items: ["Once", "Every week"], selection: $choice, anchor: 0.3)
                        .frame(width: 360)
                    HStack(alignment: .bottom, spacing: Spacing.l) {
                        BusBubble(route: "123", minutes: 4, crowd: .seats, isMine: true, transferTo: nil)
                        BusBubble(route: "45", minutes: 9, crowd: .standing, isMine: false, transferTo: "67")
                        BusBubble(route: "123", minutes: 19, crowd: .full, isMine: true, transferTo: nil)
                    }
                    LeagueProgress(level: .busSingle, levelName: "Single-Decker league", done: 18, goal: 30,
                                   nextName: "Double-Decker")
                    VoiceNote(duration: .seconds(12), isPlaying: false) {}
                    HStack(spacing: Spacing.m) {
                        Medal(.gold, size: 104)
                        Medal(.silver, size: 104)
                        Medal(.bronze, size: 104)
                        KidDot(color: CrayonColor.kidABlue)
                        KidDot(color: CrayonColor.kidBOrange, size: 28)
                    }
                }
                section("0f · Frames") {
                    let morning = Capped(["Wake up", "Toilet", "Get dressed", "Breakfast", "Brush teeth"], max: 3)
                    KidScreen {
                        Text("Good morning, Kid A").crayonType(.title)
                    } body: { _ in
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            ForEach(morning.visible, id: \.self) { Text($0).crayonType(.body) }
                            if morning.overflow > 0 { Text("+\(morning.overflow)").crayonType(.caption) }
                        }
                    }
                    .frame(height: 420)
                    GrownupScreen {
                        Text("Add a weekly activity").crayonType(.title)
                    } content: {
                        VStack(spacing: Spacing.s) {
                            ForEach(0..<6, id: \.self) { i in CrayonField("Field \(i + 1)", text: .constant("")) }
                        }
                    } primaryAction: {
                        InkButton("Save") {}
                    }
                    .frame(height: 640)
                }
            }
            .padding(GridMetrics.margin)
            .foregroundStyle(CrayonColor.ink)
        }
        .background(CrayonColor.paper)
        .navigationTitle("Design gallery")
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title).crayonType(.title)
            content()
        }
    }
}
