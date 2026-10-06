import SwiftUI

struct GPUPage: View {
    let monitor: Monitor

    var body: some View {
        let m = monitor
        page {
            LazyVGrid(columns: two, spacing: 14) {
                ChartCard(
                    title: "Usage", symbol: "square.stack.3d.up", tint: .pink, trailing: MacInfo.shared.gpuCores.map { "\($0)-core GPU" },
                    value: "\(Int(m.gpu))", unit: "%", times: m.times,
                    series: [ChartSeries(name: "GPU", values: m.gpuHistory, color: .pink)], domain: 0...100, axis: percentAxis)
                ChartCard(
                    title: "Temperature", symbol: "thermometer.medium", tint: .orange,
                    trailing: "average of \(m.sensors.filter { $0.group == "GPU" }.count) sensors",
                    value: m.gpuTemp.map { TemperatureUnit.format($0) } ?? "—", times: m.times,
                    series: [ChartSeries(name: "Temp", values: m.gpuTempHistory, color: .orange)], axis: { TemperatureUnit.format($0) })
            }
        }
    }
}
