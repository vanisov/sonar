import SwiftUI

struct ChartSeries: Identifiable {
    let name: String
    let values: Ring<Float>
    let color: Color
    var dashed = false  // drawn as a dashed line over the columns, e.g. temperature
    var scale: Double = 1  // e.g. to draw a temperature on a 0–100% axis
    var format: ((Double) -> String)?  // for the hover readout of a series in its own units; the axis formatter otherwise
    var id: String { name }
}

/// History over the chosen time range in Sonar's column style, matching the panel. One column per slice of time
/// holds that slice's peak, so spikes survive any range; a slice with no samples (the Mac was asleep) stays empty.
/// Two series draw as mirrored columns (first above the axis, second below), dashed series as lines on top.
/// One Canvas, redrawn when a sample arrives or the pointer moves; nothing animates.
struct HistoryChart: View {
    let times: Ring<Date>
    let series: [ChartSeries]
    var domain: ClosedRange<Double>?
    var height: CGFloat = 140
    let axis: (Double) -> String
    @AppStorage(Prefs.dashboardRange) private var range = TimeRange.fifteenMinutes.rawValue
    @State private var hovered: Int?

    private static let gutter: CGFloat = 64  // value labels on the left, wide enough for "0 bytes/s"
    private static let footer: CGFloat = 16  // time labels below

    var body: some View {
        GeometryReader { g in
            let timeRange = TimeRange(rawValue: range) ?? .fifteenMinutes
            let plot = CGRect(x: Self.gutter, y: 6, width: max(g.size.width - Self.gutter, 1), height: max(height - Self.footer - 6, 1))
            // About 8 pt per column, but at least 3 s of history each: samples arrive every 2 s with some timer slack,
            // so narrower columns would sometimes come up empty.
            let columns = max(12, min(Int(plot.width / 8), timeRange.rawValue / 3))
            let data = ChartColumns(times: times, series: series, range: Double(timeRange.rawValue), columns: columns)
            let scale = Scale(top: domain?.upperBound ?? data.top * 1.1, mirrored: data.bars.count == 2)
            Canvas { ctx, _ in
                draw(data, scale: scale, plot: plot, timeRange: timeRange, in: &ctx)
            }
            .overlay(alignment: .topLeading) {
                if let hovered, let text = readout(data, column: hovered) {
                    Text(text)
                        .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .fixedSize()
                        .position(x: min(max(plot.minX + data.center(hovered, in: plot.width), plot.minX + 90), g.size.width - 90), y: 0)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let p) = phase, plot.contains(CGPoint(x: p.x, y: min(p.y, plot.maxY - 1))) {
                    hovered = min(max(Int((p.x - plot.minX) / plot.width * CGFloat(columns)), 0), columns - 1)
                } else {
                    hovered = nil
                }
            }
        }
        .frame(height: height)
    }

    // MARK: Drawing

    private func draw(_ data: ChartColumns, scale: Scale, plot: CGRect, timeRange: TimeRange, in ctx: inout GraphicsContext) {
        let label = Font.system(size: 10, weight: .medium).monospacedDigit()

        // value gridlines and labels
        for value in scale.ticks {
            for y in scale.positions(of: value, in: plot) {
                ctx.stroke(
                    Path { $0.addLines([CGPoint(x: plot.minX, y: y), CGPoint(x: plot.maxX, y: y)]) }, with: .color(.primary.opacity(0.07)))
                ctx.draw(Text(axis(value)).font(label).foregroundStyle(.secondary), at: CGPoint(x: plot.minX - 8, y: y), anchor: .trailing)
            }
        }
        if scale.mirrored {
            ctx.stroke(
                Path { $0.addLines([CGPoint(x: plot.minX, y: scale.axisY(plot)), CGPoint(x: plot.maxX, y: scale.axisY(plot))]) },
                with: .color(.primary.opacity(0.15)))
        }

        // clock-aligned time labels
        let start = data.end.addingTimeInterval(-Double(timeRange.rawValue))
        let style: Date.FormatStyle = timeRange == .minute ? .dateTime.hour().minute().second() : .dateTime.hour().minute()
        for tick in timeRange.ticks(endingAt: data.end) {
            let x = plot.minX + CGFloat(tick.timeIntervalSince(start) / Double(timeRange.rawValue)) * plot.width
            ctx.stroke(
                Path { $0.addLines([CGPoint(x: x, y: plot.minY), CGPoint(x: x, y: plot.maxY)]) }, with: .color(.primary.opacity(0.05)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            ctx.draw(Text(tick.formatted(style)).font(label).foregroundStyle(.secondary), at: CGPoint(x: x, y: plot.maxY + 4), anchor: .top)
        }

        // 80% line on percentage charts
        if domain == 0...100, !scale.mirrored {
            let y = scale.positions(of: 80, in: plot)[0]
            ctx.stroke(
                Path { $0.addLines([CGPoint(x: plot.minX, y: y), CGPoint(x: plot.maxX, y: y)]) }, with: .color(.temperature.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }

        // columns
        let step = plot.width / CGFloat(data.count)
        let width = max(step * 0.7, 1.5)
        let newest = data.newest
        for (s, bars) in data.bars.enumerated() {
            let color = series.filter { !$0.dashed }[s].color
            for (c, peak) in bars.enumerated() {
                guard let peak else { continue }
                let opacity = c == newest || c == hovered ? 1 : 0.3 + 0.5 * Double(c) / Double(data.count)
                let rect = scale.column(peak, below: s == 1, x: plot.minX + CGFloat(c) * step + (step - width) / 2, width: width, in: plot)
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: min(2.5, width / 2)), with: .color(c == newest ? .signal : color.opacity(opacity))
                )
            }
        }

        // peak marker on single-series charts
        if data.bars.count == 1,
            let best = data.bars[0].indices.filter({ data.bars[0][$0] != nil }).max(by: { data.bars[0][$0]! < data.bars[0][$1]! }),
            best != newest
        {
            let top = scale.column(data.bars[0][best]!, below: false, x: 0, width: 1, in: plot).minY - 6
            ctx.fill(
                Path(ellipseIn: CGRect(x: plot.minX + data.center(best, in: plot.width) - 3, y: top - 3, width: 6, height: 6)),
                with: .color(.signal))
        }

        // dashed lines
        for (l, line) in data.lines.enumerated() {
            var path = Path()
            for (c, mean) in line.enumerated() {
                guard let mean else { continue }
                let point = CGPoint(x: plot.minX + data.center(c, in: plot.width), y: scale.positions(of: mean, in: plot)[0])
                if path.isEmpty || line[max(c - 1, 0)] == nil { path.move(to: point) } else { path.addLine(to: point) }
            }
            ctx.stroke(path, with: .color(series.filter(\.dashed)[l].color), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
        }
    }

    /// "2:14:07 PM · CPU 58% · Temperature 61 °C" for the column under the pointer.
    private func readout(_ data: ChartColumns, column c: Int) -> String? {
        guard data.bars.contains(where: { $0[c] != nil }) else { return nil }
        let bars = series.filter { !$0.dashed }, lines = series.filter(\.dashed)
        var parts = [data.time(of: c).formatted(date: .omitted, time: .standard)]
        for (s, values) in data.bars.enumerated() {
            if let v = values[c] { parts.append("\(bars[s].name) \(bars[s].format.map { $0(v / bars[s].scale) } ?? axis(v))") }
        }
        for (l, values) in data.lines.enumerated() {
            if let v = values[c] { parts.append("\(lines[l].name) \(lines[l].format.map { $0(v / lines[l].scale) } ?? axis(v))") }
        }
        return parts.joined(separator: " · ")
    }
}

/// Samples bucketed into equal slices of time ending at the newest sample.
struct ChartColumns {
    let count: Int
    let end: Date
    let slice: TimeInterval
    let bars: [[Double?]]  // peak per column, per solid series, already scaled
    let lines: [[Double?]]  // mean per column, per dashed series, already scaled
    let newest: Int  // last column with data

    var top: Double { max((bars + lines).flatMap { $0.compactMap { $0 } }.max() ?? 1, 0.000_1) }

    init(times: Ring<Date>, series: [ChartSeries], range: TimeInterval, columns: Int) {
        count = columns
        end = times.last ?? .now
        slice = range / Double(columns)
        let start = end.addingTimeInterval(-range)
        let solid = series.filter { !$0.dashed }, dashed = series.filter(\.dashed)
        var peaks = Array(repeating: [Double?](repeating: nil, count: columns), count: solid.count)
        var sums = Array(repeating: [Double](repeating: 0, count: columns), count: dashed.count)
        var counts = [Int](repeating: 0, count: columns)
        var i = times.count - 1
        while i >= 0, times[i] >= start {
            let c = min(Int(times[i].timeIntervalSince(start) / slice), columns - 1)
            for (s, ser) in solid.enumerated() where i < ser.values.count {
                let v = Double(ser.values[i]) * ser.scale
                peaks[s][c] = max(peaks[s][c] ?? v, v)
            }
            for (s, ser) in dashed.enumerated() where i < ser.values.count { sums[s][c] += Double(ser.values[i]) * ser.scale }
            counts[c] += 1
            i -= 1
        }
        bars = peaks
        lines = sums.map { s in s.indices.map { counts[$0] > 0 ? s[$0] / Double(counts[$0]) : nil } }
        newest = counts.lastIndex(where: { $0 > 0 }) ?? -1
    }

    func center(_ c: Int, in width: CGFloat) -> CGFloat { (CGFloat(c) + 0.5) * width / CGFloat(count) }
    func time(of c: Int) -> Date { end.addingTimeInterval(-slice * Double(count - 1 - c)) }
}

/// The value axis: round-number ticks, and for mirrored charts an axis line with the second series below it.
private struct Scale {
    let top: Double
    let mirrored: Bool
    let ticks: [Double]

    init(top: Double, mirrored: Bool) {
        let step = Self.niceStep(top / 3)
        self.top = max(top, step)
        self.mirrored = mirrored
        ticks = stride(from: 0, through: self.top + step * 0.001, by: step).map { $0 }
    }

    /// 1, 2, 2.5 or 5 times a power of ten.
    static func niceStep(_ raw: Double) -> Double {
        guard raw > 0 else { return 1 }
        let magnitude = pow(10, floor(log10(raw)))
        return ([1, 2, 2.5, 5, 10].first { $0 * magnitude >= raw } ?? 10) * magnitude
    }

    func axisY(_ plot: CGRect) -> CGFloat { mirrored ? plot.minY + plot.height * 0.55 : plot.maxY }

    /// Where a value sits; for mirrored charts, both above and below the axis (for gridlines and labels).
    func positions(of value: Double, in plot: CGRect) -> [CGFloat] {
        let axis = axisY(plot)
        let up = axis - CGFloat(min(value / top, 1)) * (axis - plot.minY)
        guard mirrored else { return [up] }
        let down = axis + CGFloat(min(value / top, 1)) * (plot.maxY - axis)
        return value == 0 ? [axis] : [up, down]
    }

    func column(_ value: Double, below: Bool, x: CGFloat, width: CGFloat, in plot: CGRect) -> CGRect {
        let axis = axisY(plot)
        if below {
            let h = max(CGFloat(min(value / top, 1)) * (plot.maxY - axis), 1.5)
            return CGRect(x: x, y: axis + 1, width: width, height: h)
        }
        let h = max(CGFloat(min(value / top, 1)) * (axis - plot.minY), 1.5)
        return CGRect(x: x, y: axis - h, width: width, height: h)
    }
}
