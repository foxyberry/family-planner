import Domain
import XCTest

/// Spec S2 "Matching", on made-up schools (public repo).
final class SchoolSearchTests: XCTestCase {
    private func moe(_ id: String, _ name: String, keys: [String], primary: Bool = true) -> SchoolEntry {
        SchoolEntry(id: id, name: name, kind: .moe(primary ? .primary : .secondary), area: "Example Town",
                    hasPrimary: primary, followsMoeTerms: true, hours: nil, searchKeys: keys)
    }

    private lazy var schools = [
        moe("sunny-park-primary", "Sunny Park Primary School", keys: ["sunny park", "sunny park primary", "spps"]),
        moe("sunny-park-secondary", "Sunny Park Secondary School", keys: ["sunny park", "sunny park secondary"],
            primary: false),
        moe("sunny-hill-primary", "Sunny Hill Primary School", keys: ["sunny hill", "sunny hill primary"]),
        moe("saint-example", "Saint Example's Primary School", keys: ["saint examples", "sep"]),
        SchoolEntry(id: "bay-international", name: "Sunny Bay International School",
                    kind: .other(curriculum: "IB PYP"), area: nil, hasPrimary: true, followsMoeTerms: false,
                    hours: nil, breakCount: 3, searchKeys: ["sbis"]),
    ]

    func testNormaliseFoldsCaseAccentsApostrophesAndSaint() {
        XCTAssertEqual(SchoolSearch.normalise("St. Éxample’s  Pri-School"), "saint examples pri school")
        XCTAssertEqual(SchoolSearch.normalise("Govt"), "government")
    }

    func testEveryWordStartsAWordOfAKey() {
        XCTAssertEqual(SchoolSearch.matches("sun pa", in: schools).map(\.id),
                       ["sunny-park-primary", "sunny-park-secondary"])
    }

    func testInitialsMatchAWholeKeyFirst() {
        XCTAssertEqual(SchoolSearch.matches("SPPS", in: schools).first?.id, "sunny-park-primary")
    }

    func testStMatchesSaint() {
        XCTAssertEqual(SchoolSearch.matches("st example", in: schools).map(\.id), ["saint-example"])
    }

    func testPrimaryBeforeOthersThenAToZ() {
        XCTAssertEqual(SchoolSearch.matches("sunny", in: schools).map(\.id),
                       ["bay-international", "sunny-hill-primary", "sunny-park-primary", "sunny-park-secondary"])
    }

    func testNoWordsNoMatches() {
        XCTAssertTrue(SchoolSearch.matches("  ", in: schools).isEmpty)
        XCTAssertTrue(SchoolSearch.matches("zebra", in: schools).isEmpty)
    }

    func testAtMostEight() {
        let many = (0..<12).map { moe("s\($0)", "Example \($0) Primary", keys: ["example"]) }
        XCTAssertEqual(SchoolSearch.matches("example", in: many).count, 8)
    }

    func testCaptions() {
        XCTAssertEqual(schools[0].caption, "MOE primary · Example Town")
        XCTAssertEqual(schools[1].caption, "MOE secondary · Example Town")
        XCTAssertEqual(schools[4].caption, "International · IB PYP · own term dates")
    }
}
