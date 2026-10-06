import XCTest

@testable import Sonar

final class VisiblePointsTests: XCTestCase {
    /// A history sampled at the given times (seconds), with values cycling 0…6.
    private func history(_ seconds: [Double]) -> (Ring<Date>, Ring<Float>) {
        var times = Ring<Date>(capacity: seconds.count)
        var values = Ring<Float>(capacity: seconds.count)
        for (i, t) in seconds.enumerated() {
            times.append(Date(timeIntervalSince1970: t))
            values.append(Float(i % 7))
        }
        return (times, values)
    }

    private func every2s(_ count: Int, from start: Double = 0) -> [Double] {
        (0..<count).map { start + Double($0) * 2 }
    }

    func testKeepsOnlySamplesInsideTheRange() {
        let (times, values) = history(every2s(100))  // 0…198 s
        let points = VisiblePoints(times: times, lead: values, range: 60).indices
        XCTAssertEqual(points.count, 31)  // 138…198 s
        XCTAssertEqual(points.first.map { times[$0.index].timeIntervalSince1970 }, 138)
    }

    func testStartsANewRunAfterAGap() {
        let (times, values) = history(every2s(30) + every2s(10, from: 1000))  // a sleep between 58 s and 1000 s
        let points = VisiblePoints(times: times, lead: values, range: 3600).indices
        XCTAssertEqual(points.filter { $0.run == 0 }.count, 30)
        XCTAssertEqual(points.filter { $0.run == 1 }.count, 10)
    }

    func testThinsAnHourAndKeepsPeaks() {
        let (times, values) = history(every2s(1800))
        let points = VisiblePoints(times: times, lead: values, range: 3600, limit: 240).indices
        XCTAssertLessThanOrEqual(points.count, 241)
        XCTAssertEqual(points.map { values[$0.index] }.max(), 6)
    }
}
