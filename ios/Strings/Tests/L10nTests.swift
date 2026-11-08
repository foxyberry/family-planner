import Foundation
import Strings
import XCTest

final class L10nTests: XCTestCase {
    func testKnownKeyResolvesToItsEnglishValue() {
        XCTAssertEqual(L10n.tr("lock.enter"), "Enter")
    }

    func testFormatKeyFillsInItsArgument() {
        XCTAssertEqual(L10n.tr("relock.countdown", 5), "Locks in 0:05")
        XCTAssertEqual(L10n.tr("relock.countdown", 30), "Locks in 0:30")
    }

    func testMissingKeyShowsTheKey() {
        XCTAssertEqual(L10n.tr("no.such.key"), "no.such.key")
    }

    /// The compiled catalog in Strings.bundle (inside this unhosted test bundle).
    func testEveryCatalogKeyHasAnEnglishValue() throws {
        let strings = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Strings", withExtension: "bundle")
            .flatMap(Bundle.init(url:)))
        let url = try XCTUnwrap(strings.url(forResource: "Localizable", withExtension: "strings",
                                            subdirectory: nil, localization: "en"))
        let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        XCTAssertFalse(table.isEmpty)
        for (key, value) in table {
            XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(key) has no English value")
        }
    }
}
