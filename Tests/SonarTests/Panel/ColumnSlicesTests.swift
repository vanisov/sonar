import XCTest

@testable import Sonar

final class ColumnSlicesTests: XCTestCase {
    func testFullHistoryUsesTheNewestWindow() {
        let slices = ColumnSlices(count: 1800, window: 60, columns: 30)
        XCTAssertEqual(slices.ranges.first, 1740..<1742)
        XCTAssertEqual(slices.ranges.last, 1798..<1800)
        XCTAssertTrue(slices.ranges.allSatisfy { $0.count == 2 })
    }

    func testFreshHistoryGrowsInFromTheRight() {
        let slices = ColumnSlices(count: 10, window: 60, columns: 30)
        XCTAssertTrue(slices.ranges.prefix(25).allSatisfy(\.isEmpty))
        XCTAssertEqual(slices.ranges[25], 0..<2)
        XCTAssertEqual(slices.ranges.last, 8..<10)
    }

    func testEverySampleLandsInExactlyOneColumn() {
        let slices = ColumnSlices(count: 150, window: 150, columns: 30)
        XCTAssertEqual(slices.ranges.flatMap { Array($0) }, Array(0..<150))
    }
}
