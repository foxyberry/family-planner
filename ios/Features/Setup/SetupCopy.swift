import Domain
import Foundation
import Strings

/// Everything S1–S4 print, decided here so the views only render (spec "S1–S4").
extension SetupFeature.State {
    /// "Step 2 of 4"; S3 adds the kid it asks about: "Step 3 of 4 · Kid A".
    public var stepText: String {
        let text = L10n.tr("setup.step", step.number, 4)
        guard let kid = goingKid else { return text }
        return L10n.tr("s2.school.with_area", text, kid.trimmedName)
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

    /// A time as the field prints it, or the seed placeholder ("7:30 am") in `softText`.
    public func timeLabel(_ row: SetupFeature.TimeRow) -> (text: String, isPlaceholder: Bool) {
        let school = tabKid?.school
        let (value, placeholder): (Int?, Int) = switch row {
        case .start: (school?.start, 450)
        case .end: (school?.end, 900)
        case .arriveBy: (school?.arriveBy, 450)
        case .latest: (school?.latest, 460)
        }
        return (TimeText.withPeriod(value ?? placeholder), value == nil)
    }

    /// The time the wheel opens on: the field's time, or its placeholder.
    public func timeDate(_ row: SetupFeature.TimeRow) -> Date {
        let school = tabKid?.school
        let minute = switch row {
        case .start: school?.start ?? 450
        case .end: school?.end ?? 900
        case .arriveBy: school?.arriveBy ?? 450
        case .latest: school?.latest ?? 460
        }
        return Self.wheelDay.date(minute: minute, calendar: calendar)
    }

    /// Any fixed day: the wheel picks a clock time only.
    static let wheelDay = Day(year: 2026, month: 1, day: 1)

    /// S1 swatch names for VoiceOver.
    public static func colourName(_ index: Int) -> String {
        switch index {
        case 0: L10n.tr("s1.colour.blue")
        case 1: L10n.tr("s1.colour.orange")
        case 2: L10n.tr("s1.colour.green")
        default: L10n.tr("s1.colour.purple")
        }
    }

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
    public var rideText: String { L10n.tr("c2.minutes", goingKid?.going.ride ?? 0) }
    public var leaveText: String { L10n.tr("going.leave.minutes", goingKid?.going.leaveBefore ?? 0) }

    /// "before · 7:20 am", from the school's Arrive by.
    public var leaveCaption: String? {
        guard let kid = goingKid, let arrive = kid.school.arriveBy else { return nil }
        return L10n.tr("going.leave.before", TimeText.withPeriod(max(arrive - kid.going.leaveBefore, 0)))
    }

    public var goingTimesCaption: String? {
        guard let school = goingKid?.school, let arrive = school.arriveBy, let latest = school.latest else { return nil }
        return L10n.tr("s3.side.times", TimeText.withPeriod(arrive), TimeText.withPeriod(latest))
    }

    // MARK: S4

    /// The side summary's school and way, from the first kid with a school.
    public var summarySchool: (title: String, hours: String)? {
        guard let kid = goingKids.first, let start = kid.school.start, let end = kid.school.end else { return nil }
        return (kid.school.kind == .preschool ? L10n.tr("starter.preschool") : L10n.tr("s4.school"),
                TimeText.range(start, end))
    }

    public var summaryWay: (picture: String, title: String, detail: String)? {
        guard let going = goingKids.first?.going else { return nil }
        if going.way == .bus {
            return (going.way.moverPicture, L10n.tr("s4.way.bus"), L10n.tr("s4.way.bus.detail", going.walk, going.ride))
        }
        return (going.way.moverPicture, Self.wayCaption(going.way), L10n.tr("s4.way.leave", going.leaveBefore))
    }
}
