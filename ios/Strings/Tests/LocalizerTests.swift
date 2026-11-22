import ComposableArchitecture
import Localization
import Strings
import XCTest

final class LocalizerTests: XCTestCase {
    func testEnglishCatalogResolvesKeysAndArguments() {
        XCTAssertEqual(Localizer.english.tr("lock.enter"), "Enter")
        XCTAssertEqual(Localizer.english.tr("from.gap", 30), "30 min after")
    }

    func testAppCatalogMatchesTheStaticLookup() {
        XCTAssertEqual(Localizer.app.tr("lock.enter"), L10n.tr("lock.enter"))
    }

    func testKeysShowTheKeyAndItsArguments() {
        XCTAssertEqual(Localizer.keys.tr("lock.enter"), "lock.enter")
        XCTAssertEqual(Localizer.keys.tr("from.gap", 30), "from.gap|30")
    }

    func testInjectedReadsTheDependency() {
        XCTAssertEqual(Localizer.injected, .english)
        withDependencies { $0.localizer = .keys } operation: {
            XCTAssertEqual(Localizer.injected, .keys)
        }
    }
}
