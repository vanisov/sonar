import SwiftUI

struct MemoryPage: View {
    let monitor: Monitor
    @State private var highlighted: String?

    var body: some View {
        let m = monitor
        let p = m.memoryParts
        let parts: [(String, UInt64, Color)] = [
            ("App memory", p.app, .purple), ("Wired", p.wired, .blue), ("Compressed", p.compressed, .pink),
            ("Cached files", p.cached, .teal),
        ]
        page {
            DashCard(title: "Where memory goes", symbol: "memorychip", tint: .purple, trailing: "\(Fmt.memory(m.memoryTotal)) total") {
                SegmentBar(
                    segments: parts.map { name, bytes, color in
                        SegmentBar.Segment(id: name, value: Double(bytes), color: color, details: memoryDetails(name))
                    },
                    total: Double(m.memoryTotal), format: { Fmt.memory(UInt64($0)) }, highlighted: $highlighted)
                LazyVGrid(columns: two, spacing: 0) {
                    ForEach(parts, id: \.0) { part in
                        keyValue(part.0, Fmt.memory(part.1), dot: part.2).highlights(part.0, in: $highlighted)
                    }
                    keyValue("Free", Fmt.memory(p.free), dot: .secondary)
                    keyValue("Swap used", Fmt.memory(m.swapUsed))
                }
            }
            LazyVGrid(columns: two, spacing: 14) {
                ChartCard(
                    title: "Used", symbol: "memorychip", tint: .purple, trailing: "pressure \(m.pressure.lowercased())",
                    value: m.memoryPercent.formatted(.number.precision(.fractionLength(1))), unit: "%", times: m.times,
                    series: [ChartSeries(name: "Memory", values: m.memoryHistory, color: .purple)], domain: 0...100, axis: percentAxis)
                TopApps(title: "Using the most memory", apps: Array(m.apps.prefix(8)))
            }
        }
    }

    /// What's behind each part, for its hover readout.
    private func memoryDetails(_ part: String) -> [String] {
        switch part {
        case "App memory": monitor.apps.prefix(4).map { "\($0.name)  \(Fmt.memory($0.memory))" }
        case "Wired": ["Locked in RAM by macOS and drivers; can't be compressed or swapped"]
        case "Compressed": ["Squeezed to make room; \(Fmt.memory(monitor.swapUsed)) more is swapped to disk"]
        case "Cached files": ["Recently used files kept in RAM; freed instantly when apps need it"]
        default: []
        }
    }
}
