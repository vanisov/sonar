import XCTest

@testable import Sonar

final class ChartColumnsTests: XCTestCase {
    /// Samples at the given seconds with the given values.
    private func history(_ samples: [(Double, Float)]) -> (Ring<Date>, Ring<Float>) {
        var times = Ring<Date>(capacity: samples.count), values = Ring<Float>(capacity: samples.count)
        for (t, v) in samples {
            times.append(Date(timeIntervalSince1970: t))
            values.append(v)
        }
        return (times, values)
    }

    func testEachColumnKeepsItsPeak() {
        // 60 s range, 6 columns of 10 s; samples every 2 s ending at t = 1000
        var samples: [(Double, Float)] = []
        for i in 0..<30 {
            let value: Float = i == 12 ? 90 : 10
            samples.append((942 + 2 * Double(i), value))
        }
        let (times, values) = history(samples)
        let cols = ChartColumns(times: times, series: [ChartSeries(name: "CPU", values: values, color: .blue)], range: 60, columns: 6)
        XCTAssertEqual(cols.bars[0].compactMap { $0 }.max(), 90)
        XCTAssertEqual(cols.bars[0].filter { $0 == 90 }.count, 1)  // the spike lands in one column only
        XCTAssertEqual(cols.newest, 5)
    }

    func testSleepLeavesEmptyColumns() {
        // samples only in the first and last 10 s of a 60 s range
        let (times, values) = history([(940, 20), (945, 20), (995, 30), (1000, 30)])
        let cols = ChartColumns(times: times, series: [ChartSeries(name: "CPU", values: values, color: .blue)], range: 60, columns: 6)
        XCTAssertEqual(cols.bars[0].map { $0 == nil }, [false, true, true, true, true, false])
    }

    func testDashedSeriesAveragesAndScales() {
        let (times, temps) = history([(991, 50), (993, 70)])
        let (_, usage) = history([(991, 10), (993, 10)])
        let cols = ChartColumns(
            times: times,
            series: [
                ChartSeries(name: "CPU", values: usage, color: .blue),
                ChartSeries(name: "Temperature", values: temps, color: .orange, dashed: true, scale: 0.5),
            ], range: 10, columns: 1)
        XCTAssertEqual(cols.lines[0][0], 30)  // mean of 50 and 70, times 0.5
    }
}
