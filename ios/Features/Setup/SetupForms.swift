import Domain
import Foundation
import Grownup
import Strings

/// One kid card in S1 and the kid's answers in S2 and S3.
public struct KidEntry: Equatable, Identifiable {
    /// From this age a kid has a school in S2; younger kids have "no school yet" and skip S3.
    public static let schoolAge = 6
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

    public init(id: UUID, colorIndex: Int) {
        self.id = id
        self.colorIndex = colorIndex
    }

    public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The age typed, when it is a whole number from 1 to 18.
    public var age: Int? { Int(ageText.trimmingCharacters(in: .whitespaces)).flatMap { (1...18).contains($0) ? $0 : nil } }

    public var hasSchool: Bool { (age ?? 0) >= Self.schoolAge }

    /// The name, or "Child 2" while it is empty (tabs, captions).
    public func shownName(index: Int) -> String {
        trimmedName.isEmpty ? L10n.tr("s1.child", index + 1) : trimmedName
    }
}

/// S2 for one kid: the school from the list (or typed by hand), its days and times, and its terms.
public struct SchoolForm: Equatable, Sendable {
    /// Letters typed before the list opens.
    public static let searchFrom = 2

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
    /// The MOE terms check, or the answer to "Does your school follow the MOE term dates?".
    public var usesMoeTerms = false
    /// The pill tapped for that question (nil: none yet).
    public var moeAnswer: Bool?

    public init() {}

    public var name: String? {
        if let picked { return picked.name }
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return typedByHand && !typed.isEmpty ? typed : nil
    }

    /// The list is open from 2 letters until a school is picked or typed by hand.
    public var isListOpen: Bool {
        picked == nil && !typedByHand && text.filter(\.isLetter).count >= Self.searchFrom
    }

    public var isComplete: Bool {
        guard name != nil, !days.isEmpty, let start, let end, let arriveBy, let latest else { return false }
        return start < end && arriveBy <= latest && latest < end
    }

    /// What the MOE terms row shows (spec S2 "MOE terms row").
    public enum TermsRow: Equatable, Sendable {
        case check(isOn: Bool)
        case ownDates(breaks: Int)
        case ask(answer: Bool?)
    }

    public var termsRow: TermsRow? {
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
