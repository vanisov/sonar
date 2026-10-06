import XCTest

@testable import Sonar

final class FmtTests: XCTestCase {
    func testUptime() {
        XCTAssertEqual(Fmt.uptime(3 * 3600 + 12 * 60), "3h 12m")
        XCTAssertEqual(Fmt.uptime(13 * 86400 + 6 * 3600 + 59 * 60), "13d 6h")
        XCTAssertEqual(Fmt.uptime(59), "0h 0m")
    }

    func testSplitsValueAndUnit() {
        XCTAssertTrue(Fmt.split("293.11 GB") == ("293.11", "GB"))
        XCTAssertTrue(Fmt.split("12 kB/s") == ("12", "kB/s"))
        XCTAssertTrue(Fmt.split("Off") == ("Off", ""))
    }
}
