import XCTest

@testable import Sonar

final class CleanScannerTests: XCTestCase {
    func testMeasuresEverythingInsideAFolder() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appending(path: "nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(count: 100_000).write(to: dir.appending(path: "a.bin"))
        try Data(count: 50_000).write(to: dir.appending(path: "nested/b.bin"))

        let (size, lastWrite) = CleanScanner.scan(dir)
        XCTAssertGreaterThanOrEqual(size, 150_000)  // allocated size rounds up to whole blocks
        XCTAssertLessThan(size, 200_000)
        XCTAssertLessThan(abs(lastWrite.timeIntervalSinceNow), 60)
    }

    func testMissingPathIsEmpty() {
        let (size, _) = CleanScanner.scan(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        XCTAssertEqual(size, 0)
    }
}
