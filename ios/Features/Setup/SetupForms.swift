import Domain
import Foundation
import Grownup
import Strings

/// Where a kid goes in the day (S2 "Goes to"; user, 2026-11-09: preschool from about 2, so age
/// only sets the default).
public enum GoesTo: Hashable, Sendable, CaseIterable {
    case school, preschool, home
}

/// One kid card in S1 and the kid's answers in S2 and S3.
public struct KidEntry: Equatable, Identifiable {
    /// From this age "School" is picked in S2; younger kids start with nothing picked.
    public static let schoolAge = 7
    public static let colours = 4

    public var id: UUID
    public var name = ""
    public var ageText = ""
    /// 0 blue, 1 orange, 2 green, 3 purple (`CrayonColor.kidPalette`).
    public var colorIndex: Int
    /// `kidGirl` or `kidBoy`; nil until tapped (the name field shows the colour dot until then).
    public var face: String?
    public var school = SchoolForm()
    public var going = GoingForm()
    /// The grown-up's pick in S2's "Goes to" row; nil until tapped.
    public var goesToChoice: GoesTo?

    public init(id: UUID, colorIndex: Int) {
        self.id = id
        self.colorIndex = colorIndex
    }

    public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The age typed, when it is a whole number from 1 to 18.
    public var age: Int? { Int(ageText.trimmingCharacters(in: .whitespaces)).flatMap { (1...18).contains($0) ? $0 : nil } }

    /// The pick, or "School" from age 7 (spec S2: nothing picked for younger kids).
    public var goesTo: GoesTo? { goesToChoice ?? ((age ?? 0) >= Self.schoolAge ? .school : nil) }

    /// A kid who goes out in the day (school or preschool): S3 asks how they get there.
    public var goesOut: Bool { goesTo == .school || goesTo == .preschool }

    /// S2 is done for this kid: a pick, and for school or preschool a complete form.
    public var placeIsComplete: Bool {
        switch goesTo {
        case .home: true
        case .school, .preschool: school.isComplete
        case nil: false
        }
    }

    /// The name, or "Child 2" while it is empty (tabs, captions).
    public func shownName(index: Int) -> String {
        trimmedName.isEmpty ? L10n.tr("s1.child", index + 1) : trimmedName
    }
}

/// S2 for one kid: the school from the list (or typed by hand), its days and times, and its terms.
public struct SchoolForm: Equatable, Sendable {
    /// Letters typed before the list opens.
    public static let searchFrom = 2

    /// School: the search form; preschool: a typed name, days and hours only (spec S2).
    public var kind: SchoolKind = .school
    public var text = ""
    public var picked: SchoolEntry?
    /// "Not in the list?" was tapped: `text` is the school's name.
    public var typedByHand = false
    public var matches: [SchoolEntry] = []
    public var days: Set<Weekday> = Weekday.schoolDays
    public var start: Int?
    public var end: Int?
    public var arriveBy: Int?
    public var latest: Int?
    /// "From the school website, checked 9 Nov" while Hours, Arrive by and Latest are as the school
    /// website states them; editing a value removes it.
    public var hoursSource: String?
    /// The website's hours for weekdays that differ, kept while the hours are as the site states them.
    public var websiteDays: [Weekday: SchoolDayHours] = [:]
    /// The MOE terms check, or the answer to "Does your school follow the MOE term dates?".
    public var usesMoeTerms = false
    /// The pill tapped for that question (nil: none yet).
    public var moeAnswer: Bool?

    public init() {}

    public var name: String? {
        if kind == .school, let picked { return picked.name }
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (typedByHand || kind == .preschool) && !typed.isEmpty ? typed : nil
    }

    /// The list is open from 2 letters until a school is picked or typed by hand.
    public var isListOpen: Bool {
        kind == .school && picked == nil && !typedByHand && text.filter(\.isLetter).count >= Self.searchFrom
    }

    public var isComplete: Bool {
        guard name != nil, !days.isEmpty, let start, let end, start < end else { return false }
        if kind == .preschool { return true }
        guard let arriveBy, let latest else { return false }
        return arriveBy <= latest && latest < end
    }

    /// What the MOE terms row shows (spec S2 "MOE terms row").
    public enum TermsRow: Equatable, Sendable {
        case check(isOn: Bool)
        case ownDates(breaks: Int)
        case ask(answer: Bool?)
    }

    public var termsRow: TermsRow? {
        guard kind == .school else { return nil }
        if let picked {
            switch picked.followsMoeTerms {
            case true?: return .check(isOn: usesMoeTerms)
            case false?: return .ownDates(breaks: picked.breakCount)
            case nil: return .ask(answer: moeAnswer)
            }
        }
        return typedByHand ? .ask(answer: moeAnswer) : nil
    }
}

/// S3 for one kid with a school: how they go, and by bus the stop, buses, walk and ride.
public struct GoingForm: Equatable {
    public static let ways: [Way] = [.walk, .bus, .car, .taxi]
    public static let defaultLeave = 10

    public var way: Way = .bus
    public var search = StopSearchFeature.State()
    public var services: [String] = []
    public var walk = BusPlan.defaultWalk
    public var ride = BusPlan.defaultRide
    /// Walk, car or taxi: minutes before the school starts.
    public var leaveBefore = GoingForm.defaultLeave

    public init() {}

    /// By bus the kid leaves the walk and the ride before the start, rounded up to 5 minutes.
    public var trip: Trip {
        guard way == .bus else { return Trip(way: way, leaveBefore: leaveBefore) }
        return Trip(way: .bus, leaveBefore: min((walk + ride + 4) / 5 * 5, 90))
    }
}
