import XCTest

@testable import Sonar

final class RingTests: XCTestCase {
    func testKeepsInsertionOrderBeforeFull() {
        var ring = Ring<Int>(capacity: 3)
        ring.append(1)
        ring.append(2)
        XCTAssertEqual(Array(ring), [1, 2])
    }

    func testOverwritesOldestOnceFull() {
        var ring = Ring<Int>(capacity: 3)
        for v in 1...5 { ring.append(v) }
        XCTAssertEqual(Array(ring), [3, 4, 5])
        XCTAssertEqual(ring.count, 3)
        XCTAssertEqual(ring.last, 5)
    }
}
