import XCTest

@testable import Sonar

final class UpdaterTests: XCTestCase {
    func testComparesNumericallyNotAlphabetically() {
        XCTAssertTrue(Updater.isNewer("1.10.0", than: "1.9.2"))
        XCTAssertTrue(Updater.isNewer("2.0", than: "1.99.99"))
        XCTAssertFalse(Updater.isNewer("1.9.2", than: "1.10.0"))
    }

    func testEqualVersionsAreNotNewer() {
        XCTAssertFalse(Updater.isNewer("1.6.0", than: "1.6.0"))
        XCTAssertFalse(Updater.isNewer("1.6", than: "1.6.0"))
    }

    func testPrereleaseIsOlderThanItsRelease() {
        XCTAssertFalse(Updater.isNewer("1.5.0-beta.1", than: "1.5.0"))  // must never downgrade a release to its beta
        XCTAssertTrue(Updater.isNewer("1.5.0", than: "1.5.0-beta.1"))
        XCTAssertTrue(Updater.isNewer("1.6.0-beta.1", than: "1.5.0"))
    }

    func testOrdersPrereleases() {
        XCTAssertTrue(Updater.isNewer("1.5.0-beta.10", than: "1.5.0-beta.9"))
        XCTAssertTrue(Updater.isNewer("1.5.0-rc.1", than: "1.5.0-beta.3"))
        XCTAssertTrue(Updater.isNewer("1.5.0-beta.1.1", than: "1.5.0-beta.1"))
    }
}
