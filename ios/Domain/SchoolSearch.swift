import Foundation
import Strings

/// One school in the bundled school lists (spec "S2 · School"): the MOE list from data.gov.sg and,
/// in a private build, the international and private schools. Public data only.
public struct SchoolEntry: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// An MOE school, by level.
        case moe(MoeLevel)
        /// An international or other private school, with its first curriculum when known.
        case other(curriculum: String?)
    }

    public enum MoeLevel: Hashable, Sendable { case primary, primaryAndSecondary, secondary }

    public var id: String
    public var name: String
    public var kind: Kind
    /// MOE planning area in display case ("Woodlands"); nil for other schools.
    public var area: String?
    public var hasPrimary: Bool
    /// true / false as the school publishes it; nil when not known. MOE schools are always true.
    public var followsMoeTerms: Bool?
    /// Daily hours stated on the school's own website, when known.
    public var hours: SchoolHours?
    /// How many breaks and holidays the school website lists (own term dates).
    public var breakCount: Int
    /// `searchKeys` from the data, normalised as `SchoolSearch.normalise` does.
    public let keys: [String]
    let keyWords: [[String]]
    let normalisedName: String

    public init(id: String, name: String, kind: Kind, area: String?, hasPrimary: Bool, followsMoeTerms: Bool?,
                hours: SchoolHours?, breakCount: Int = 0, searchKeys: [String]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.area = area
        self.hasPrimary = hasPrimary
        self.followsMoeTerms = followsMoeTerms
        self.hours = hours
        self.breakCount = breakCount
        let keys = (searchKeys + [name]).map(SchoolSearch.normalise).filter { !$0.isEmpty }
        self.keys = keys
        keyWords = keys.map { $0.split(separator: " ").map(String.init) }
        normalisedName = SchoolSearch.normalise(name)
    }

    /// The caption under the name in the match list and under a picked school (spec S2):
    /// "MOE primary · Woodlands", "International · IB PYP · own term dates".
    public var caption: String {
        switch kind {
        case let .moe(level):
            let levelText = switch level {
            case .primary: L10n.tr("s2.school.moe.primary")
            case .primaryAndSecondary: L10n.tr("s2.school.moe.mixed")
            case .secondary: L10n.tr("s2.school.moe.secondary")
            }
            return area.map { L10n.tr("s2.school.with_area", levelText, $0) } ?? levelText
        case let .other(curriculum):
            var text = L10n.tr("s2.school.international")
            if let curriculum { text = L10n.tr("s2.school.with_area", text, curriculum) }
            if followsMoeTerms == false { text = L10n.tr("s2.school.with_area", text, L10n.tr("s2.school.own_terms")) }
            return text
        }
    }
}

/// A school's daily hours from its own website (`school-hours.json`, `dailyHours`).
public struct SchoolHours: Hashable, Sendable {
    /// When pupils must be there (minutes after midnight).
    public var start: Int
    /// Dismissal; nil when the site does not say.
    public var end: Int?
    /// The day the website was read.
    public var checked: Day

    public init(start: Int, end: Int?, checked: Day) {
        self.start = start
        self.end = end
        self.checked = checked
    }
}

/// Type a name, pick from matches (spec S2 "Matching").
public enum SchoolSearch {
    /// The most matches the list shows.
    public static let most = 8

    /// Lower case, no accents or apostrophes, "st" → "saint", "govt" → "government", anything else
    /// that is not a letter or digit → one space.
    public static func normalise(_ text: String) -> String {
        let plain = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
        let spaced = String(plain.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return spaced.split(separator: " ").map { word -> String in
            switch word {
            case "st": "saint"
            case "govt": "government"
            default: String(word)
            }
        }.joined(separator: " ")
    }

    /// Every typed word starts a word of one key, or the whole text equals a key (initials such as
    /// "PLMGS"). Order: exact key, name prefix, word prefix; primary first; then A–Z. At most 8.
    public static func matches(_ text: String, in schools: [SchoolEntry]) -> [SchoolEntry] {
        let query = normalise(text)
        let words = query.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let ranked: [(rank: Int, school: SchoolEntry)] = schools.compactMap { school in
            if school.keys.contains(query) { return (0, school) }
            if school.normalisedName.hasPrefix(query) { return (1, school) }
            let found = school.keyWords.contains { keyWords in
                words.allSatisfy { word in keyWords.contains { $0.hasPrefix(word) } }
            }
            return found ? (2, school) : nil
        }
        return ranked.sorted { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            if a.school.hasPrimary != b.school.hasPrimary { return a.school.hasPrimary }
            return a.school.name.localizedStandardCompare(b.school.name) == .orderedAscending
        }
        .prefix(most).map(\.school)
    }
}
