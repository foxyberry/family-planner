import AppSettings
import DesignSystem
import Domain
import Foundation
import Grownup
import KitArt
import Strings

/// Everything S1–S4 print, decided here so the views only render (spec "S1–S4").
extension SetupFeature.State {
    /// The shared kid card's words (spec "Kid card").
    public var kidCardWords: KidCard.Words { .kid(strings) }

    /// "Step 2 of 4" (S3's kid tabs say whose route it is).
    public var stepText: String { strings.tr("setup.step", step.number, 4) }

    /// One kid tab on S2 or S3: the shown name and the face in the kid's colour.
    public struct KidTab: Equatable, Sendable {
        public let id: KidEntry.ID
        public let name: String
        public let face: String
        public let colorIndex: Int
    }

    /// S2: a tab for every kid. S3: a tab for every kid who goes out.
    public var kidTabs: [KidTab] {
        let shown = step == .gettingThere ? goingKids : kids.elements
        return shown.map { kid in
            KidTab(id: kid.id, name: kid.shownName(index: kids.index(id: kid.id) ?? 0), face: kid.face ?? "",
                   colorIndex: kid.colorIndex)
        }
    }

    /// The selected tab of the step on screen.
    public var selectedKidTab: KidEntry.ID {
        step == .gettingThere ? (goingKid?.id ?? schoolTab) : schoolTab
    }

    /// Layout v17: with 3–4 kids the tabs show the face only (88 × 72).
    public var kidTabsAreFaceOnly: Bool { kidTabs.count >= 3 }

    /// S3 tabs whose route is not finished yet (a hurry dot on the face).
    public var unfinishedGoingTabs: Set<KidEntry.ID> {
        Set(goingKids.filter { !$0.going.isFinished }.map(\.id))
    }

    public var title: String {
        switch step {
        case .family: L10n.tr("s1.title")
        case .school: L10n.tr("s2.title")
        case .gettingThere: L10n.tr("s3.title")
        case .almostDone: L10n.tr("s4.title")
        }
    }

    /// S1 has no ←.
    public var showsBack: Bool { step != .family }

    public var primaryTitle: String { step == .almostDone ? L10n.tr("s4.start") : L10n.tr("setup.next") }

    // MARK: S2

    /// The "Goes to" tabs, in board order.
    public static let places: [(GoesTo, String)] = [
        (.school, L10n.tr("s2.goes.school")), (.preschool, L10n.tr("s2.goes.preschool")), (.home, L10n.tr("s2.goes.home")),
    ]

    /// "{Name} is at home in the day." on an at-home kid's tab.
    public var atHomeLine: String? {
        guard let kid = tabKid, kid.goesTo == .home, let index = kids.index(id: kid.id) else { return nil }
        return L10n.tr("s2.at_home", kid.shownName(index: index))
    }

    /// The S2 side column on a Preschool or At-home tab (the medals show only for a school).
    public var placeSide: (body: String, caption: String)? {
        guard let kid = tabKid, let index = kids.index(id: kid.id) else { return nil }
        let name = kid.shownName(index: index)
        switch kid.goesTo {
        case .preschool: return (L10n.tr("s2.side.preschool", name), L10n.tr("s2.side.preschool.caption"))
        case .home: return (L10n.tr("s2.side.home", name), L10n.tr("s2.side.home.caption"))
        default: return nil
        }
    }

    public var schoolPlaceholder: String {
        tabKid?.school.kind == .preschool ? L10n.tr("s2.preschool.placeholder") : L10n.tr("s2.school.placeholder")
    }

    /// The caption under the school field (spec S2).
    public var schoolCaption: String {
        guard let school = tabKid?.school else { return "" }
        if school.kind == .preschool { return L10n.tr("s2.preschool.hint") }
        if let picked = school.picked { return picked.caption }
        if school.typedByHand { return L10n.tr("s2.school.typed") }
        if school.isListOpen { return school.matches.isEmpty ? L10n.tr("s2.school.none") : L10n.tr("s2.school.pick") }
        return L10n.tr("s2.school.hint")
    }

    /// A field's time: the form's value (it starts on the defaults), or the default if one is unset.
    func timeMinute(_ row: SetupFeature.TimeRow) -> (value: Int, isSet: Bool) {
        let school = tabKid?.school ?? SchoolForm()
        let fresh = SchoolForm()
        let (value, fallback): (Int?, Int?) = switch row {
        case .start: (school.start, fresh.start)
        case .end: (school.end, fresh.end)
        case .arriveBy: (school.arriveBy, fresh.arriveBy)
        case .latest: (school.latest, fresh.latest)
        }
        return (value ?? fallback ?? 0, value != nil)
    }

    /// A time as the field prints it; in `softText` only when the form has no value for it.
    public func timeLabel(_ row: SetupFeature.TimeRow) -> (text: String, isPlaceholder: Bool) {
        let time = timeMinute(row)
        return (TimeText.withPeriod(time.value), !time.isSet)
    }

    /// The time the wheel opens on: the field's time.
    public func timeDate(_ row: SetupFeature.TimeRow) -> Date {
        Self.wheelDay.date(minute: timeMinute(row).value, calendar: calendar)
    }

    /// Any fixed day: the wheel picks a clock time only.
    static let wheelDay = Day(year: 2026, month: 1, day: 1)

    /// S3 "Going" captions.
    public static func wayCaption(_ way: Way) -> String {
        switch way {
        case .walk: L10n.tr("going.walk")
        case .bus: L10n.tr("going.bus")
        case .car: L10n.tr("going.car")
        case .taxi, .shuttle: L10n.tr("going.taxi")
        }
    }

    public var termsCaption: String? {
        guard case let .ownDates(breaks)? = tabKid?.school.termsRow else { return nil }
        return breaks > 0 ? L10n.tr("s2.terms.breaks", breaks) : L10n.tr("s2.terms.later")
    }

    /// The side column's medal captions, filled from Arrive by and Latest (spec S2 side column).
    public var medalCaptions: (gold: String, silver: String, bronze: String) {
        let school = tabKid?.school
        let arrive = (school?.arriveBy).map(TimeText.withPeriod)
        let latest = (school?.latest).map(TimeText.withPeriod)
        return (L10n.tr("s2.medal.gold.caption"),
                arrive.map { L10n.tr("s2.medal.silver.caption", $0) } ?? L10n.tr("s2.medal.silver.caption.empty"),
                latest.map { L10n.tr("s2.medal.bronze.caption", $0) } ?? L10n.tr("s2.medal.bronze.caption.empty"))
    }

    // MARK: S3

    public var walkText: String { L10n.tr("c2.minutes", goingKid?.going.walk ?? 0) }
    /// Spec "Several buses": one Ride row per picked bus in pill order ("on 12"), the label "Ride" on
    /// the first only; before a bus is picked, one Ride row for what the ride covers.
    public var rideRows: [RideRow] {
        guard let going = goingKid?.going else { return [] }
        guard !going.services.isEmpty else {
            return [RideRow(service: nil, label: L10n.tr("c2.ride"), minutes: going.ride,
                            text: L10n.tr("c2.minutes", going.ride), caption: L10n.tr("s3.ride.caption"))]
        }
        return going.services.enumerated().map { index, service in
            let minutes = going.ride(on: service)
            return RideRow(service: service, label: index == 0 ? L10n.tr("c2.ride") : "", minutes: minutes,
                           text: L10n.tr("c2.minutes", minutes), caption: L10n.tr("c2.ride.on", service))
        }
    }
    /// Spec "Several buses" (v61): each bus that changes is one more pill in the Buses row, as on C2.
    public var changePills: [BusSettingsFeature.ChangePill] {
        BusSettingsFeature.ChangePill.pills(goingKid?.going.changes ?? [], join: strings.tr("bus.join"))
    }

    /// The Buses row shows pills once the stop's buses are known (or a bus that changes exists).
    public var hasBusPills: Bool {
        guard let going = goingKid?.going else { return false }
        return !going.search.servicesAtStop.isEmpty || !going.changes.isEmpty
    }

    /// The link under the last Ride row (v61, always shown): "+ A bus that changes…".
    public var changeLink: String { strings.tr("c2.change_link") }

    /// C2c over S3 for one of the going kid's buses that change (`index`), or a new one (nil).
    func changeEditor(index: Int?) -> ChangeBusesFeature.State? {
        guard let going = goingKid?.going else { return nil }
        return ChangeBusesFeature.State(ourStop: going.search, changes: going.changes, index: index, ride: going.ride)
    }

    public var leaveText: String { L10n.tr("going.leave.minutes", goingKid?.going.leaveBefore ?? 0) }

    /// The Leave row's caption as shown: "before · 7:20 am", or nothing without an Arrive by.
    public var leaveCaptionText: String { leaveCaption ?? "" }

    /// "before · 7:20 am", from the school's Arrive by.
    public var leaveCaption: String? {
        guard let kid = goingKid, let arrive = kid.school.arriveBy else { return nil }
        return L10n.tr("going.leave.before", TimeText.withPeriod(max(arrive - kid.going.leaveBefore, 0)))
    }

    // MARK: S4

    /// The side summary's school and way, from the first kid with a school.
    public var summarySchool: (title: String, hours: String)? {
        guard let kid = goingKids.first, let start = kid.school.start, let end = kid.school.end else { return nil }
        return (kid.school.kind == .preschool ? L10n.tr("starter.preschool") : L10n.tr("s4.school"),
                TimeText.hours(start, end))
    }

    public var summaryWay: (picture: String, title: String, detail: String)? {
        guard let going = goingKids.first?.going else { return nil }
        if going.way == .bus {
            // Board S4: the red single-deck bus, as on the "Live bus times" row.
            return (KitSlot.busSingle.rawValue, L10n.tr("s4.way.bus"), L10n.tr("s4.way.bus.detail", going.walk, going.ride))
        }
        return (going.way.moverPicture, Self.wayCaption(going.way), L10n.tr("s4.way.leave", going.leaveBefore))
    }

    /// S4's switch rows (spec "S4 · Almost done"), shared with Settings' Family tab.
    public var settingRows: [AppSettingRow] { settings.rows(lockNeedsFaceID: lockNeedsFaceID, touchID: isTouchID) }
}

/// An S3 Ride row: one bus's ride (`service` nil before a bus is picked).
public struct RideRow: Equatable, Identifiable, Sendable {
    public var service: String?
    public var label: String
    public var minutes: Int
    public var text: String
    public var caption: String
    public var id: String { service ?? "" }
}

extension KidEntry {
    /// The face inside the S1 Name field, in the kid's colour (no picture until one is picked).
    public var badge: KidFace.Badge { KidFace.Badge(face: pickedFace, colorIndex: colorIndex) }
    /// The picked face's slot name, or none.
    public var pickedFace: String { face ?? "" }
}
