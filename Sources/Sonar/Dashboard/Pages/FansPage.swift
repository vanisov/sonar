import SwiftUI

struct FansPage: View {
    let monitor: Monitor

    var body: some View {
        let m = monitor
        page {
            if m.fanHistories.isEmpty {
                ContentUnavailableView("This Mac has no fans", systemImage: "fan", description: Text("It's cooled passively."))
            }
            LazyVGrid(columns: two, spacing: 14) {
                ForEach(m.fanHistories.indices, id: \.self) { i in
                    let rpm = i < m.fanRPMs.count ? m.fanRPMs[i] : 0
                    let limits = i < m.fanLimits.count ? m.fanLimits[i] : (min: 0, max: 0)
                    ChartCard(
                        title: m.fanHistories.count == 2 ? (i == 0 ? "Left fan" : "Right fan") : "Fan \(i + 1)", symbol: "fan", tint: .teal,
                        trailing: m.fansAuto ? "managed by macOS" : "manual",
                        value: "\(Int(rpm))", unit: rpm < 1 ? "RPM · stopped" : "RPM", times: m.times,
                        series: [ChartSeries(name: "Fan", values: m.fanHistories[i], color: .teal)],
                        domain: 0...max(limits.max, 1000), axis: { "\(Int($0))" })
                }
            }
        }
    }
}
