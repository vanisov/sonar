import XCTest

@testable import Sonar

final class MonitorTests: XCTestCase {
    func testCounterDropsCountAsNoGrowth() {
        XCTAssertEqual(Monitor.delta(150, 100), 50)
        XCTAssertEqual(Monitor.delta(100, 150), 0)  // e.g. a drive was ejected: the sum went down
    }

    func testRatePerSecond() {
        XCTAssertEqual(Monitor.rate(3000, 1000, over: 2), 1000)
        XCTAssertEqual(Monitor.rate(1000, 3000, over: 2), 0)
        XCTAssertEqual(Monitor.rate(3000, 1000, over: 0), 0)
    }

    func testStartTimeIdentifiesAProcess() throws {
        let start = try XCTUnwrap(Monitor.startTime(of: getpid()))
        XCTAssertEqual(Monitor.startTime(of: getpid()), start)  // stable for the same process
        XCTAssertLessThan(Date().timeIntervalSince1970 - Double(start) / 1_000_000, 86_400)
        XCTAssertNil(Monitor.startTime(of: 99_999_999))
    }
}
