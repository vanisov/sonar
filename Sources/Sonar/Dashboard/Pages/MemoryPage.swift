import SwiftUI

struct MemoryPage: View {
    let monitor: Monitor

    var body: some View {
        let m = monitor
        let p = m.memoryParts
        let parts: [(String, UInt64, Color)] = [
            ("App memory", p.app, .purple), ("Wired", p.wired, .blue), ("Compressed", p.compressed, .pink),
            ("Cached files", p.cached, .teal),
        ]
        page {
            DashCard(title: "Where memory goes", symbol: "memorychip", tint: .purple, trailing: "\(Fmt.memory(m.memoryTotal)) total") {
                GeometryReader { g in
                    HStack(spacing: 2) {
                        ForEach(parts, id: \.0) { part in
                            Rectangle().fill(part.2).frame(width: max(0, g.size.width * Double(part.1) / Double(m.memoryTotal) - 2))
                        }
                        Spacer(minLength: 0)
                    }
                    .background(.primary.opacity(0.07))
                    .clipShape(Capsule())
                }
                .frame(height: 14)
                LazyVGrid(columns: two, spacing: 0) {
                    ForEach(parts, id: \.0) { part in keyValue(part.0, Fmt.memory(part.1), dot: part.2) }
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
}
