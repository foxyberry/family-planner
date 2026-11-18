import ComposableArchitecture
import Localization
import Strings
import XCTest

final class LocalizerTests: XCTestCase {
    func testEnglishCatalogResolvesKeysAndArguments() {
        XCTAssertEqual(Localizer.english.tr("lock.enter"), "Enter")
        XCTAssertEqual(Localizer.english.tr("relock.countdown", 30), "Locks in 0:30")
    }

    func testAppCatalogMatchesTheStaticLookup() {
        XCTAssertEqual(Localizer.app.tr("lock.enter"), L10n.tr("lock.enter"))
    }

    func testKeysShowTheKeyAndItsArguments() {
        XCTAssertEqual(Localizer.keys.tr("lock.enter"), "lock.enter")
        XCTAssertEqual(Localizer.keys.tr("relock.countdown", 30), "relock.countdown|30")
    }

    func testInjectedReadsTheDependency() {
        XCTAssertEqual(Localizer.injected, .english)
        withDependencies { $0.localizer = .keys } operation: {
            XCTAssertEqual(Localizer.injected, .keys)
        }
    }
}
