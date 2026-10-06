import SwiftUI

struct CPUPage: View {
    let monitor: Monitor

    var body: some View {
        let m = monitor
        page {
            LazyVGrid(columns: two, spacing: 14) {
                ChartCard(
                    title: "Usage", symbol: "cpu", tint: .blue, value: m.cpu.formatted(.number.precision(.fractionLength(1))), unit: "%",
                    times: m.times, series: [ChartSeries(name: "CPU", values: m.cpuHistory, color: .blue)], domain: 0...100,
                    axis: percentAxis)
                ChartCard(
                    title: "Temperature", symbol: "thermometer.medium", tint: .orange,
                    trailing: Prefs.bool(Prefs.cpuTempSource, default: false)
                        ? "hottest sensor" : "average of \(m.sensors.filter { $0.group == "CPU" }.count) sensors",
                    value: m.cpuTemp.map { TemperatureUnit.format($0) } ?? "—", times: m.times,
                    series: [ChartSeries(name: "Temp", values: m.cpuTempHistory, color: .orange)], axis: { TemperatureUnit.format($0) })
            }
            DashCard(
                title: "Cores", symbol: "cpu", tint: .blue,
                trailing: "\(m.cores - m.efficiencyCores) performance · \(m.efficiencyCores) efficiency"
            ) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(m.coreUsage.enumerated()), id: \.offset) { i, usage in
                        let efficiency = i < m.efficiencyCores
                        VStack(spacing: 4) {
                            LevelBar(fraction: usage / 100, color: efficiency ? .teal : .blue, vertical: true, cornerRadius: 5)
                                .frame(height: 70)
                            Text(efficiency ? "E\(i + 1)" : "P\(i - m.efficiencyCores + 1)").font(.caption2).foregroundStyle(.secondary)
                        }
                        .help("\(Fmt.percent(usage))")
                    }
                }
                HStack(spacing: 16) {
                    Label {
                        Text("Performance")
                    } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(.blue)
                    }
                    Label {
                        Text("Efficiency")
                    } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(.teal)
                    }
                    Spacer()
                    Text(
                        "Load average \(m.loadAverage.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: " · "))"
                    )
                    .foregroundStyle(.secondary).monospacedDigit()
                }
                .labelStyle(DotLabel())
                .font(.caption)
            }
            TopApps(title: "Using the most CPU", apps: Array(m.apps.sorted { $0.cpu > $1.cpu }.prefix(6)))
        }
    }
}
