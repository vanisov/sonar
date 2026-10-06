import XCTest

@testable import Sonar

final class ShortcutTests: XCTestCase {
    func testStorageRoundTrips() {
        let shortcut = Shortcut(storage: "2:2304:⌥⌘D")
        XCTAssertEqual(shortcut?.keyCode, 2)
        XCTAssertEqual(shortcut?.modifiers, 2304)
        XCTAssertEqual(shortcut?.display, "⌥⌘D")
        XCTAssertEqual(shortcut?.storage, "2:2304:⌥⌘D")
    }

    func testDisplayMayContainColons() {
        XCTAssertEqual(Shortcut(storage: "41:256:⌘:")?.display, "⌘:")
    }

    func testRejectsMalformedStorage() {
        XCTAssertNil(Shortcut(storage: ""))
        XCTAssertNil(Shortcut(storage: "x:256:⌘A"))
        XCTAssertNil(Shortcut(storage: "2:256"))
    }
}
