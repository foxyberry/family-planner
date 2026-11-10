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
    private let onBack: (() -> Void)?

    /// `onBack` shows the crayon Back button in a header (parent mode); previews leave it out.
    public init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if let onBack {
                    GrownupHeader(title: "Design gallery", onBack: onBack)
                }
                section("0b · Controls") {
                    InkButton("Missions") {}
                    HStack(spacing: Spacing.m) {
                        RoundButton(glyph: .chevronLeft, accessibilityLabel: "Back") {}
                        RoundButton(glyph: .plus, accessibilityLabel: "Add") {}
                        RoundButton(glyph: .close, accessibilityLabel: "Remove") {}.size(48)
                        // G0: the pencil way in.
                        RoundButton(picture: .pencil, accessibilityLabel: "Grown-up mode") {}
                        RoundButton(picture: .pencil, accessibilityLabel: "Grown-up mode") {}.look(.night)
                        // G1 Undo (on) and Redo (off, at 45 %).
                        RoundButton(glyph: .undo, accessibilityLabel: "Undo") {}.size(72)
                        RoundButton(glyph: .redo, accessibilityLabel: "Redo") {}.size(72).opacity(0.45)
                        PillToggle("12", isOn: true) {}
                        PillToggle("34", isOn: false) {}
                        CrayonSwitch(isOn: true)
                        CrayonSwitch(isOn: false)
                        CheckMark(isDone: true)
                        CheckMark(isDone: false)
                    }
                    CrayonTabs(selection: $tab, items: [(0, "Kid A", KidFace.Badge(face: "kidGirl", colorIndex: 0)), (1, "Kid B", KidFace.Badge(face: "kidBoy", colorIndex: 1)), (2, "Family", nil)])
                    HStack(spacing: Spacing.s) {
                        DayChip("M", isOn: $monday)
                        DayChip("T", isOn: $tuesday)
                        DateChip(weekday: "Mon", day: 9, isOn: true) {}
                        DateChip(weekday: "Tue", day: 10, isOn: false) {}
                        DateChip(weekday: "Wed", day: 11, isOn: false, isToday: true, compact: true) {}
                    }
                    HStack(spacing: Spacing.m) {
                        CrayonField("Activity name", text: $name).frame(width: 480)
                        TimeField(label: "7:30 am", time: $time)
                        DateField(label: "9 Nov", date: $time)
                        FieldButton("End of term") {}
                    }
                    // S1–S4: setup progress, kid colour swatches, a time not chosen yet.
                    HStack(spacing: Spacing.m) {
                        StepDots(current: 2)
                        HStack(spacing: Spacing.xs) {
                            ForEach(0..<4, id: \.self) { index in
                                ColourSwatch(colorIndex: index, isPicked: index == 0, accessibilityLabel: "Colour") {}
                            }
                        }
                        TimeField(label: "7:30 am", time: $time, isPlaceholder: true)
                        KidFace(.init(face: "", colorIndex: 2), name: "Kid C")
                        LockMark(size: 56)
                    }
                    CrayonTabs(selection: .constant(0), items: [(0, "School", nil), (1, "Preschool", nil), (2, "At home", nil)],
                               itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm)
                    PictureRow(slots: [.actSwim, .actArt, .actMusic, .actPiano, .actDance], selection: .constant(.actSwim),
                               all: [.actSwim, .actArt], isShowingAll: false, moreTitle: "More", moreLabel: "More pictures") {}
                    IconPicker(selection: $picture, slots: [.actSwim, .actDance, .actArt, .actMusic, .actStory, .actCCA]) {}
                    // Spec "Event form rows", Bring: several picks, up to 4.
                    IconPicker(picked: [.backpack, .waterBottle], slots: [.backpack, .lunchBox, .waterBottle]) { _ in }
                    HStack(spacing: Spacing.xl) {
                        TimeLeft(minutes: 19)
                        TimeLeft(minutes: -2)
                    }
                    SlideToGo(state: .idle, idleTitle: "Slide to go", doneTitle: "On our way!") {}
                    SlideToGo(state: .done, idleTitle: "", doneTitle: "On our way!") {}
                    SlideToGo(state: .done, idleTitle: "", doneTitle: "Ready!", knob: .star, doneKnob: .crown) {}
                }
                section("0c · Content") {
                    ListRow(leading: "7:30") { Text("Bus to school") }
                    SettingRow(title: "Grown-up lock", caption: "Face ID before grown-up screens", isOn: true, action: {}) {
                        LockMark(size: 56)
                    }
                    .frame(width: 738)
                    ResultListCard(rows: [
                        .init(id: "1", title: "Opp Example Hotel With A Very Long Name Past The Card", caption: "Example Rd · 00000") {},
                        .init(id: "2", title: "Example Primary School", caption: "Example Rd · 00001") {},
                        .init(id: "3", glyph: .plus, title: "Not in the list? Type the name") {},
                    ], visibleRows: 6, seed: 55)
                    HStack(spacing: 0) {
                        FormLabel("Name")
                        Text("Swimming").crayonType(.body)
                    }
                    .environment(\.formLabelWidth, 128)
                    TodayRow(leading: "Today") { Text("Swimming 15:30") }
                    PreviewRow(time: "3:30 pm", isNew: false) { Text("Play").crayonType(.body) }
                    PreviewRow(time: "4:00 pm", isNew: true) { Text("Swimming").crayonType(.head) }
                    PaperCard { Text("A sheet of paper").crayonType(.body) }
                    PickerPopover(title: "Repeat", items: ["Once", "Every week"], selection: $choice, anchor: 0.3)
                        .frame(width: 360)
                    LeagueProgress(level: .busSingle, levelName: "Single-Decker league", done: 18, goal: 30,
                                   nextName: "Double-Decker")
                    VoiceNote(duration: .seconds(12), isPlaying: false) {}
                    HStack(spacing: Spacing.m) {
                        Medal(.gold, size: 104)
                        Medal(.silver, size: 104)
                        Medal(.bronze, size: 104)
                        KidFace(.init(face: "kidGirl", colorIndex: 0), name: "Kid A")
                        KidFace(.init(face: "kidBoy", colorIndex: 1), name: "Kid B", size: KidFace.medium)
                    }
                }
                section("M2 · Home and lock") {
                    PieClock(sectors: [
                        ClockSector(start: 0, end: 420, style: .sleep, iconName: "actSleep", isCurrent: false,
                                    showsStar: false, priority: 0),
                        ClockSector(start: 480, end: 900, style: .school, iconName: "actSchool", isCurrent: false,
                                    showsStar: false, priority: 0),
                        ClockSector(start: 930, end: 990, style: .afterSchool, iconName: "actSwim", isCurrent: true,
                                    showsStar: false, priority: 1),
                        ClockSector(start: 1230, end: 1440, style: .sleep, iconName: "actSleep", isCurrent: false,
                                    showsStar: false, priority: 0),
                    ], now: 945, hub: .init(title: "Swimming", subtitle: "until 4:30 pm"))
                    .scaleEffect(0.5)
                    .frame(width: 480, height: 480)
                    KidNowNext(now: "teddy", next: "actPlay")
                    ConfirmCard(title: "Leave without adding?", message: nil, cancel: "Keep editing", confirm: "Leave",
                                isDestructive: false, onCancel: {}, onConfirm: {})
                    FromWhenCard(title: "Change from when?", tabs: [(0, "Today"), (1, "Next Mon"), (2, "Date")],
                                 selection: .constant(0), dateChoice: 2, dateLabel: "17 Nov", date: .constant(Date(timeIntervalSince1970: 1_800_000_000)),
                                 caption: nil, save: "Save", cancel: "Cancel", onSave: {}, onCancel: {})
                }
                section("0b · Marker glyphs") {
                    HStack(spacing: Spacing.m) {
                        ForEach(MarkerGlyph.allCases, id: \.self) { MarkerIcon($0, size: 40) }
                    }
                }
                section("0c2 · Kid parts") {
                    HStack(spacing: Spacing.m) {
                        CrayonRing(progress: 0.5, colorIndex: 0)
                        KidBand(colorIndex: 1).frame(width: 340, height: 100)
                        MissionCircle(picture: .toothbrush, name: "Teeth", colorIndex: 0, isDone: true, isCurrent: false)
                        MissionCircle(picture: .shirt, name: "Get dressed", colorIndex: 0, isDone: false, isCurrent: true)
                        MissionCircle(.tick, name: "3 done", colorIndex: 0)
                        MissionCircle(.text("+3"), name: "3 more", colorIndex: 0)
                    }
                    GlyphText("Drag %@ to change the order.", glyph: .handle, color: CrayonColor.softText)
                }
                section("A2 · Live bubbles") {
                    HStack(alignment: .bottom, spacing: Spacing.l) {
                        LiveBusBubble(service: "1", minutes: "28 min",
                                      kind: .mine(face: KidFace.Badge(face: "kidGirl", colorIndex: 0), name: "Kid A",
                                                  myBus: "my bus"))
                        LiveBusBubble(service: "1", minutes: "4 min", kind: .tooSoon("too soon"))
                    }
                }
                section("F1–F4 · Form cards") {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        PickRow("End of this term", caption: "Fri 20 Nov", isPicked: true) {}
                        PickRow("No end", isPicked: false) {}
                    }
                    FormCard(title: "Ends", size: CGSize(width: 560, height: 420), done: "Done", cancel: "Cancel",
                             onDone: {}, onCancel: {}) {
                        PickRow("No end", isPicked: true) {}
                    }
                    .frame(height: 520)
                }
                section("G1 · Day button, picker, save changes") {
                    DayButton(today: "Today", date: "Tue 10 Nov") {}.frame(width: 382)
                    DayPickerCard(month: "November", weeks: Self.sampleWeeks, earlier: "Earlier", later: "Later",
                                  today: "Today", onPage: { _ in }, onPick: { _ in }, onToday: {})
                    SaveChangesCard(title: "Save the changes?", line: "Dinner 6:30 pm %@ 7:30 pm, this day",
                                    save: "Save", discard: "Don't save", cancel: "Cancel",
                                    onSave: {}, onDiscard: {}, onCancel: {})
                }
                section("C3g · Going") {
                    ChoiceCircles([.init(id: "none", picture: nil, caption: "None", isPicked: false),
                                   .init(id: "walk", picture: .shoe, caption: "Walk", isPicked: false),
                                   .init(id: "bus", picture: .busDouble, caption: "Bus", isPicked: false),
                                   .init(id: "car", picture: .car, caption: "Car", isPicked: true),
                                   .init(id: "taxi", picture: .taxi, caption: "Taxi", isPicked: false)]) { _ in }
                }
                section("A3 · Medal on the ring") {
                    HStack(spacing: Spacing.l) {
                        ForEach(MedalKind.allCases, id: \.self) { kind in
                            ZStack {
                                CrayonRing(progress: 1, colorIndex: 0)
                                KidFace(KidFace.Badge(face: "kidGirl", colorIndex: 0), name: "Kid A", size: 56)
                            }
                            .overlay(alignment: .topLeading) { MedalBadge(kind, ring: 76) }
                        }
                    }
                }
                section("A2 · Live status") {
                    HStack(spacing: Spacing.l) {
                        StatusDot("On time", tone: .onTime)
                        StatusDot("Leave now!", tone: .hurry)
                        StatusDot("Ask a grown-up", tone: .quiet)
                    }
                    HStack(spacing: Spacing.l) {
                        StatusDot("On time", tone: .onTime, compact: true)
                        NumberPlate("1", isMine: true, small: true)
                    }
                }
                section("A2 · Way strip") {
                    WayStrip(trip: .init(destination: .wolfie, destinationLabel: "School", homeLabel: "Our stop",
                                         showsStops: true, mover: .busDouble, moverX: WayStrip.liveX(minutes: 12),
                                         cardTitle: "School at 7:30 am", cardCaption: "by bus · timetable",
                                         owner: KidFace.Badge(face: "kidGirl", colorIndex: 0), ownerName: "Kid A"))
                        .frame(height: 340)
                    WayStrip(homeAllDay: "Home all day").frame(height: 340)
                    HStack(spacing: Spacing.l) {
                        DrivingKitIcon(.busDouble, size: 120)
                        DrivingKitIcon(.busShuttle, size: 120)
                        DrivingKitIcon(.car, size: 104)
                        DrivingKitIcon(.shoe, size: 96)
                    }
                }
                section("C6 · Edit clock parts") {
                    HStack(spacing: Spacing.m) {
                        ClockKnob(.idle)
                        ClockKnob(.dragging)
                        ClockKnob(.locked)
                        PlusGlyph(size: 40)
                    }
                }
                section("0g3 · Picture rigs (tap to play)") {
                    RigPlayground()
                }
                section("0f · Frames") {
                    KidFullScreen {
                        Text("Home: the clock uses the whole screen").crayonType(.head).padding(Spacing.m)
                    }
                    .frame(height: 160)
                    KidFullScreen(look: .night) {
                        HStack(spacing: Spacing.l) {
                            SkySwitch(look: .night, isAnimating: false, label: "Night. Tap for day.") {}
                            Text("Night look").crayonType(.head)
                            KitPlate(look: .night, size: 72) { KitIcon(.actDinner, size: 72) }
                            InkButton("Diary", arrow: true, look: .night) {}.frame(width: 384)
                        }
                        .padding(Spacing.m)
                    }
                    .frame(height: 160)
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
        .background(CrayonColor.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title).crayonType(.title)
            content()
        }
    }
}

/// Taps play each picture's rig once (spec "Picture rigs"); wolfie has no rig and hops whole.
private struct RigPlayground: View {
    @State private var plays: [KitSlot: Int] = [:]
    private let slots: [KitSlot] = [.actBreakfast, .toothbrush, .actSwim, .flagKR, .busSingle, .wolfie]

    var body: some View {
        HStack(spacing: Spacing.m) {
            ForEach(slots, id: \.self) { slot in
                RiggedKitIcon(slot, size: 104, playID: plays[slot, default: 0])
                    .onTapGesture { plays[slot, default: 0] += 1 }
            }
        }
    }
}

extension ComponentGallery {
    /// Two weeks from Mon 9 Nov, today Tue 10, Sat 14 picked.
    public static let sampleWeeks: [[DayPickerCard.Chip]] = (0..<2).map { week in
        (0..<7).map { day in
            let index = 7 * week + day
            return DayPickerCard.Chip(index: index, weekday: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day],
                                      day: 9 + index, isPicked: index == 5, isToday: index == 1)
        }
    }
}
