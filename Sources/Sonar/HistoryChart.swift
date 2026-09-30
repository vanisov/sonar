import Charts
import SwiftUI

/// The dashboard's time range. Stored in seconds under `Prefs.dashboardRange`.
enum TimeRange: Int, CaseIterable, Identifiable {
    case minute = 60, fiveMinutes = 300, fifteenMinutes = 900, halfHour = 1800, hour = 3600

    var id: Int { rawValue }

    var short: String {
        switch self {
        case .minute: "1m"
        case .fiveMinutes: "5m"
        case .fifteenMinutes: "15m"
        case .halfHour: "30m"
        case .hour: "1h"
        }
    }

    var long: String {
        switch self {
        case .minute: "Last minute"
        case .fiveMinutes: "Last 5 minutes"
        case .fifteenMinutes: "Last 15 minutes"
        case .halfHour: "Last 30 minutes"
        case .hour: "Last hour"
        }
    }

    /// Spacing of the time axis labels.
    var tick: (component: Calendar.Component, count: Int) {
        switch self {
        case .minute: (.second, 15)
        case .fiveMinutes: (.minute, 1)
        case .fifteenMinutes: (.minute, 5)
        case .halfHour: (.minute, 10)
        case .hour: (.minute, 15)
        }
    }
}

struct ChartSeries: Identifiable {
    let name: String
    let values: Ring<Float>
    let color: Color
    var dashed = false
    var scale: Double = 1  // e.g. to draw a temperature on a 0–100% axis
    var id: String { name }
}

/// Samples inside the chosen range, grouped into runs (a new run starts after a sampling pause, e.g. sleep),
/// and thinned to at most `limit` points so an hour of 2-second samples stays cheap to draw.
/// Each point's `id` is its time (or its clock-aligned bucket when thinned), so thinned points don't jump between
/// buckets as new samples arrive. Charts aren't animated: Swift Charts re-lays out every mark per frame (~35% CPU).
struct VisiblePoints {
    typealias Point = (index: Int, run: Int, id: Double)
    let indices: [Point]

    init(times: Ring<Date>, lead: Ring<Float>?, range: TimeInterval, limit: Int = 240) {
        guard let end = times.last else {
            indices = []
            return
        }
        let start = end.addingTimeInterval(-range)
        var all: [Point] = []
        var run = 0
        for i in 0..<times.count where times[i] >= start {
            if let last = all.last, times[i].timeIntervalSince(times[last.index]) > 10 { run += 1 }
            all.append((i, run, times[i].timeIntervalSince1970))
        }
        guard all.count > limit, let lead else {
            indices = all
            return
        }
        // Fixed time buckets (a multiple of the 2 s sample interval), keeping each bucket's peak so spikes stay
        // visible. Buckets are aligned to the clock, so they don't shift between updates.
        let bucket = max(2, (range / Double(limit) / 2).rounded(.up) * 2)
        var thinned: [Point] = []
        for p in all {
            let key = (p.id / bucket).rounded(.down) * bucket
            if let last = thinned.last, last.id == key, last.run == p.run {
                if lead[p.index] > lead[last.index] { thinned[thinned.count - 1] = (p.index, p.run, key) }
            } else {
                thinned.append((p.index, p.run, key))
            }
        }
        indices = thinned
    }

    /// Min, average and max of a series over these points.
    func stats(_ values: Ring<Float>) -> (min: Double, avg: Double, max: Double)? {
        let v = indices.compactMap { $0.index < values.count ? Double(values[$0.index]) : nil }
        guard let lo = v.min(), let hi = v.max() else { return nil }
        return (lo, v.reduce(0, +) / Double(v.count), hi)
    }
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
        .chartPlotStyle { $0.clipped().padding(.trailing, 34) }  // room for the newest time label
        .chartXScale(domain: end.addingTimeInterval(-Double(range))...end)
        .chartYScale(domain: (domain?.lowerBound ?? 0)...top)
        .chartXAxis {
            AxisMarks(values: .stride(by: timeRange.tick.component, count: timeRange.tick.count)) {
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

/// Min / Average / Max for the visible range.
struct RangeStats: View {
    let times: Ring<Date>
    let values: Ring<Float>
    let format: (Double) -> String
    @AppStorage(Prefs.dashboardRange) private var range = TimeRange.fifteenMinutes.rawValue

    var body: some View {
        if let s = VisiblePoints(times: times, lead: nil, range: Double(range)).stats(values) {
            HStack(spacing: 8) {
                stat("Min", s.min)
                stat("Average", s.avg)
                stat("Max", s.max)
            }
        }
    }

    private func stat(_ label: String, _ v: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(format(v)).font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
