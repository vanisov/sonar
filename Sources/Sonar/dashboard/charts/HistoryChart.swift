import Charts
import SwiftUI

struct ChartSeries: Identifiable {
    let name: String
    let values: Ring<Float>
    let color: Color
    var dashed = false
    var scale: Double = 1  // e.g. to draw a temperature on a 0–100% axis
    var id: String { name }
}

struct HistoryChart: View {
    let times: Ring<Date>
    let series: [ChartSeries]
    var domain: ClosedRange<Double>?
    var height: CGFloat = 140
    let axis: (Double) -> String
    @AppStorage(Prefs.dashboardRange) private var range = TimeRange.fifteenMinutes.rawValue
    @AppStorage(Prefs.chartFilled) private var filled = true

    var body: some View {
        let timeRange = TimeRange(rawValue: range) ?? .fifteenMinutes
        let points = VisiblePoints(times: times, lead: series.first?.values, range: Double(range)).indices
        let top =
            domain?.upperBound ?? max(points.flatMap { p in series.map { Double($0.values[p.index]) * $0.scale } }.max() ?? 1, 1) * 1.1
        let end = times.last ?? .now
        Chart {
            ForEach(series) { s in
                ForEach(points, id: \.id) { p in
                    let value = Double(s.values[p.index]) * s.scale
                    LineMark(x: .value("Time", times[p.index]), y: .value("Value", value), series: .value("Series", "\(s.name) \(p.run)"))
                        .foregroundStyle(s.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: s.dashed ? [4, 3] : []))
                    if filled, !s.dashed, s.id == series.first?.id {
                        AreaMark(
                            x: .value("Time", times[p.index]), y: .value("Value", value), series: .value("Series", "\(s.name) \(p.run)")
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [s.color.opacity(0.25), s.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    }
                }
            }
        }
        .chartPlotStyle { $0.clipped() }
        .chartXScale(domain: end.addingTimeInterval(-Double(range))...end)
        .chartYScale(domain: (domain?.lowerBound ?? 0)...top)
        .chartXAxis {
            AxisMarks(values: timeRange.ticks(endingAt: end)) {
                AxisGridLine()
                AxisValueLabel(format: timeRange == .minute ? .dateTime.hour().minute().second() : .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(axis(d)) } }
            }
        }
        .frame(height: height)
    }
}
