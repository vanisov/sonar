import SwiftUI

/// Sonar's graph style: rounded columns that brighten toward now, with the newest column in signal orange (the same
/// shape as the app icon). Each column is the peak of its slice of history, so a short spike is never averaged away.
/// Drawn with Canvas and only redrawn when a sample arrives or the pointer moves; nothing animates.
struct ColumnGraph: View {
    let values: Ring<Float>
    let tint: Color
    var window = 60  // samples shown; 60 = 2 min
    var columns = 30
    var top: Float? = 100  // nil scales to the largest value shown
    var threshold: Float?  // dashed line, e.g. 80%
    var overlay: Ring<Float>?  // a second series with the same indices, drawn as a dashed line (e.g. temperature)
    var overlayScale: (Float) -> Float = { $0 }  // maps an overlay value onto the graph's scale
    var markPeak = false
    var tooltip: ((Range<Int>) -> String)?  // absolute indices into `values` under the pointer

    @State private var hovered: Int?

    var body: some View {
        let slices = ColumnSlices(count: values.count, window: window, columns: columns)
        let peaks = slices.ranges.map { r in r.map { values[$0] }.max() }
        let scale = top ?? max(peaks.compactMap { $0 }.max() ?? 1, 1)
        GeometryReader { g in
            let layout = ColumnLayout(width: g.size.width, columns: columns)
            Canvas { ctx, size in
                let h = size.height
                if let threshold {
                    let y = h - CGFloat(threshold / scale) * (h - 2)
                    ctx.stroke(
                        Path { $0.addLines([CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)]) },
                        with: .color(.temperature.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                for (c, peak) in peaks.enumerated() {
                    guard let peak else { continue }
                    let height = max(2.5, CGFloat(min(peak / scale, 1)) * (h - 2))
                    let rect = CGRect(x: layout.x(c), y: h - height, width: layout.width, height: height)
                    let newest = c == columns - 1
                    let shading = newest ? Color.signal : tint.opacity(c == hovered ? 0.95 : 0.3 + 0.5 * Double(c) / Double(columns))
                    ctx.fill(Path(roundedRect: rect, cornerRadius: min(2.2, layout.width / 2)), with: .color(shading))
                }
                if let overlay {
                    var line = Path()
                    for (c, r) in slices.ranges.enumerated() where !r.isEmpty {
                        let mean = r.map { overlayScale(overlay[$0]) }.reduce(0, +) / Float(r.count)
                        let point = CGPoint(x: layout.center(c), y: h - CGFloat(min(mean / scale, 1)) * (h - 2))
                        if line.isEmpty { line.move(to: point) } else { line.addLine(to: point) }
                    }
                    ctx.stroke(line, with: .color(.temperature), style: StrokeStyle(lineWidth: 1.4, dash: [3, 2.5]))
                }
                if markPeak, let best = peaks.indices.filter({ peaks[$0] != nil }).max(by: { peaks[$0]! < peaks[$1]! }), best != columns - 1
                {
                    let y = h - CGFloat(min(peaks[best]! / scale, 1)) * (h - 2) - 6
                    ctx.fill(Path(ellipseIn: CGRect(x: layout.center(best) - 3, y: y - 3, width: 6, height: 6)), with: .color(.signal))
                }
            }
            .overlay(alignment: .topLeading) {
                if let hovered, let tooltip, !slices.ranges[hovered].isEmpty {
                    GraphTooltip(text: tooltip(slices.ranges[hovered]))
                        .position(x: min(max(layout.center(hovered), 60), g.size.width - 60), y: -12)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard tooltip != nil else { return }
                if case .active(let p) = phase { hovered = layout.column(at: p.x) } else { hovered = nil }
            }
        }
    }
}

/// Network: download columns rise above the axis and upload columns hang below it. Both use a log scale, so
/// 40 kB/s and 40 MB/s are both readable on one graph.
struct MirrorColumnGraph: View {
    let down: Ring<Float>
    let up: Ring<Float>
    var window = 60
    var columns = 30
    var tooltip: ((Range<Int>) -> String)?

    @State private var hovered: Int?

    /// 100 B/s → 0, 100 MB/s → 1.
    private static func level(_ bytes: Float) -> CGFloat { CGFloat(min(max((log10(max(bytes, 1)) - 2) / 6, 0), 1)) }

    var body: some View {
        let slices = ColumnSlices(count: down.count, window: window, columns: columns)
        GeometryReader { g in
            let layout = ColumnLayout(width: g.size.width, columns: columns)
            Canvas { ctx, size in
                let axis = size.height * 0.58
                for (c, r) in slices.ranges.enumerated() where !r.isEmpty {
                    let newest = c == columns - 1
                    let opacity = newest || c == hovered ? 1 : 0.3 + 0.5 * Double(c) / Double(columns)
                    let dh = max(1.5, Self.level(r.map { down[$0] }.max() ?? 0) * (axis - 2))
                    let uh = max(1.5, Self.level(r.map { up[$0] }.max() ?? 0) * (size.height - axis - 1))
                    let radius = min(1.6, layout.width / 2)
                    ctx.fill(
                        Path(roundedRect: CGRect(x: layout.x(c), y: axis - dh, width: layout.width, height: dh), cornerRadius: radius),
                        with: .color(newest ? .signal : Color.green.opacity(opacity)))
                    ctx.fill(
                        Path(roundedRect: CGRect(x: layout.x(c), y: axis + 1, width: layout.width, height: uh), cornerRadius: radius),
                        with: .color(newest ? .signal.opacity(0.85) : Color.teal.opacity(opacity * 0.85)))
                }
            }
            .overlay(alignment: .topLeading) {
                if let hovered, let tooltip, !slices.ranges[hovered].isEmpty {
                    GraphTooltip(text: tooltip(slices.ranges[hovered]))
                        .position(x: min(max(layout.center(hovered), 80), g.size.width - 80), y: -12)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard tooltip != nil else { return }
                if case .active(let p) = phase { hovered = layout.column(at: p.x) } else { hovered = nil }
            }
        }
    }
}

/// Which samples fall in each column. History is right-aligned, so a fresh history grows in from the right.
struct ColumnSlices {
    let ranges: [Range<Int>]  // absolute indices into the ring; empty for columns not sampled yet

    init(count: Int, window: Int, columns: Int) {
        let first = count - min(count, window)  // oldest sample shown
        let offset = window - (count - first)  // empty slots before it
        ranges = (0..<columns).map { c in
            let lo = max(c * window / columns - offset, 0), hi = max((c + 1) * window / columns - offset, 0)
            return (first + lo)..<(first + hi)
        }
    }
}

private struct ColumnLayout {
    let width: CGFloat  // of one column
    let step: CGFloat
    let columns: Int

    init(width total: CGFloat, columns: Int) {
        let gap: CGFloat = 2.5
        self.columns = columns
        width = max((total - gap * CGFloat(columns - 1)) / CGFloat(columns), 1)
        step = width + gap
    }

    func x(_ c: Int) -> CGFloat { CGFloat(c) * step }
    func center(_ c: Int) -> CGFloat { x(c) + width / 2 }
    func column(at x: CGFloat) -> Int { min(max(Int(x / step), 0), columns - 1) }
}

private struct GraphTooltip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold)).monospacedDigit()
            .padding(.horizontal, 6).padding(.vertical, 2)
            // Solid on purpose: a material here adds a visual-effect view inside the panel's own, which changed how
            // the whole panel blended with the desktop while the pointer was over a graph.
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .fixedSize()
            .allowsHitTesting(false)
    }
}
