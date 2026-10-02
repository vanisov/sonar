import XCTest

@testable import Sonar

final class TimeRangeTests: XCTestCase {
    func testTicksAreClockAligned() {
        let end = Date(timeIntervalSince1970: 1_000_000_123)
        for range in TimeRange.allCases {
            for tick in range.ticks(endingAt: end) {
                XCTAssertEqual(tick.timeIntervalSince1970.truncatingRemainder(dividingBy: range.tickSeconds), 0, "\(range)")
            }
        }
    }

    func testTicksStayInsideTheRangeAndClearOfTheRightEdge() {
        let end = Date(timeIntervalSince1970: 1_000_000_123)
        for range in TimeRange.allCases {
            let ticks = range.ticks(endingAt: end)
            XCTAssertFalse(ticks.isEmpty, "\(range)")
            let start = end.addingTimeInterval(-Double(range.rawValue))
            let lastAllowed = end.addingTimeInterval(-Double(range.rawValue) * 0.12)
            XCTAssertTrue(ticks.allSatisfy { $0 >= start && $0 <= lastAllowed }, "\(range)")
        }
    }
}
