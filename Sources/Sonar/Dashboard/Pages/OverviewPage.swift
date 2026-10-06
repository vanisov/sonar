import SwiftUI

struct OverviewPage: View {
    let monitor: Monitor
    @AppStorage(Prefs.overlayTemperature) private var overlay = true

    var body: some View {
        let m = monitor
        return page {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                DashCard(title: "Uptime") { Text(Fmt.uptime(m.uptime)).font(.title3.weight(.semibold)).monospacedDigit() }
                DashCard(title: "Memory pressure") { Pill(text: m.pressure, color: pressureColor(m.pressure)) }
                DashCard(title: "Thermal state") { Pill(text: ThermalState.current.title, color: ThermalState.current.color) }
                DashCard(title: "Fans") {
                    HStack {
                        Text(m.fanRPMs.max().map { $0 < 1 ? "Off" : "\(Int($0)) RPM" } ?? "None").font(.title3.weight(.semibold))
                            .monospacedDigit()
                        if !m.fanRPMs.isEmpty { Pill(text: m.fansAuto ? "Auto" : "Manual") }
                    }
                }
            }
            LazyVGrid(columns: two, spacing: 14) {
                open(.cpu) {
                    DashCard(title: "CPU", symbol: "cpu", tint: .blue, trailing: "Details ›") {
                        HStack(spacing: 24) {
                            BigValue(value: m.cpu.formatted(.number.precision(.fractionLength(1))), unit: "%", caption: "Usage", dot: .blue)
                            if let t = m.cpuTemp { BigValue(value: TemperatureUnit.format(t), caption: "Temperature", dot: .orange) }
                        }
                        HistoryChart(
                            times: m.times, series: usage(m.cpuHistory, .blue, temp: m.cpuTempHistory), domain: 0...100, height: 120,
                            axis: percentAxis)
                    }
                }
                open(.gpu) {
                    DashCard(title: "GPU", symbol: "square.stack.3d.up", tint: .pink, trailing: "Details ›") {
                        HStack(spacing: 24) {
                            BigValue(value: "\(Int(m.gpu))", unit: "%", caption: "Usage", dot: .pink)
                            if let t = m.gpuTemp { BigValue(value: TemperatureUnit.format(t), caption: "Temperature", dot: .orange) }
                        }
                        HistoryChart(
                            times: m.times, series: usage(m.gpuHistory, .pink, temp: m.gpuTempHistory), domain: 0...100, height: 120,
                            axis: percentAxis)
                    }
                }
                open(.memory) {
                    DashCard(title: "Memory", symbol: "memorychip", tint: .purple, trailing: "Details ›") {
                        BigValue(
                            value: Fmt.memory(m.memoryUsed),
                            caption: "of \(Fmt.memory(m.memoryTotal)) · pressure \(m.pressure.lowercased())")
                        HistoryChart(
                            times: m.times, series: [ChartSeries(name: "Memory", values: m.memoryHistory, color: .purple)], domain: 0...100,
                            height: 120, axis: percentAxis)
                    }
                }
                open(.network) {
                    DashCard(title: "Network", symbol: "network", tint: .green, trailing: "Details ›") {
                        HStack(spacing: 24) {
                            BigValue(value: Fmt.rate(m.down), caption: "Download", dot: .green)
                            BigValue(value: Fmt.rate(m.up), caption: "Upload", dot: .teal)
                        }
                        HistoryChart(
                            times: m.times,
                            series: [
                                ChartSeries(name: "Down", values: m.downHistory, color: .green),
                                ChartSeries(name: "Up", values: m.upHistory, color: .teal),
                            ], height: 120, axis: { Fmt.rate($0) })
                    }
                }
            }
            LazyVGrid(columns: three, spacing: 14) {
                open(.disk) {
                    DashCard(title: "Disk", symbol: "internaldrive", tint: .orange, trailing: "›") {
                        BigValue(value: Fmt.storage(m.diskFree), caption: "free of \(Fmt.storage(m.diskTotal))")
                        UsageBar(fraction: m.diskTotal > 0 ? Double(m.diskTotal - m.diskFree) / Double(m.diskTotal) : 0, color: .orange)
                    }
                }
                open(.fans) {
                    DashCard(title: "Fans", symbol: "fan", tint: .teal, trailing: "›") {
                        BigValue(
                            value: m.fanRPMs.max().map { "\(Int($0))" } ?? "—", unit: m.fanRPMs.isEmpty ? "" : "RPM",
                            caption: m.fanRPMs.isEmpty ? "No fans" : m.fansAuto ? "Managed by macOS" : "Manually controlled")
                    }
                }
                open(.apps) {
                    DashCard(title: "Top app", symbol: "square.grid.2x2", tint: .signal, trailing: "›") {
                        if let app = m.apps.first {
                            BigValue(value: app.name, caption: "\(Fmt.memory(app.memory)) · \(Fmt.percent(app.cpu, decimals: 1)) CPU")
                        }
                    }
                }
            }
        }
    }

    private func usage(_ values: Ring<Float>, _ color: Color, temp: Ring<Float>) -> [ChartSeries] {
        var series = [ChartSeries(name: "Usage", values: values, color: color)]
        if overlay { series.append(ChartSeries(name: "Temperature", values: temp, color: .orange, dashed: true, scale: tempScale)) }
        return series
    }

    private func open(_ section: DashboardSection, @ViewBuilder _ content: () -> some View) -> some View {
        Button {
            DashboardNavigation.shared.section = section
        } label: {
            content()
        }.buttonStyle(CardButtonStyle())
    }
}
