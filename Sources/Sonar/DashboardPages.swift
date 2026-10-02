import SwiftUI

// MARK: Building blocks

/// A dashboard card: quiet fill so the numbers carry the page.
struct DashCard<Content: View>: View {
    var title: String?
    var symbol: String?
    var tint: Color = .secondary
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 7) {
                    if let symbol { Image(systemName: symbol).foregroundStyle(tint) }
                    Text(title).foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    if let trailing { Text(trailing).foregroundStyle(.tertiary).font(.caption) }
                }
                .font(.subheadline.weight(.semibold))
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.07)))
    }
}

/// A big number with its unit and a caption, e.g. "34.1 %  Usage".
struct BigValue: View {
    let value: String
    var unit = ""
    var caption: String?
    var dot: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
            if let caption {
                HStack(spacing: 5) {
                    if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                    Text(caption)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = .signal

    var body: some View {
        Text(text).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color).background(color.opacity(0.15), in: Capsule())
    }
}

private func page(@ViewBuilder _ content: () -> some View) -> some View {
    ScrollView {
        VStack(spacing: 14) { content() }.padding(20)
    }
}

private let percentAxis: (Double) -> String = { Fmt.percent($0) }
private let two = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
private let three = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

/// Temperatures ride on 0–100% usage axes: 110 °C maps to the top.
private let tempScale = 100.0 / 110.0

private func pressureColor(_ pressure: String) -> Color { pressure == "Critical" ? .red : pressure == "Warning" ? .orange : .green }

// MARK: Overview

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

struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        LevelBar(fraction: fraction, color: color, cornerRadius: 4).frame(height: 8)
    }
}

enum ThermalState {
    case nominal, fair, serious, critical

    static var current: ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        default: .nominal
        }
    }

    var title: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        }
    }

    var color: Color {
        switch self {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }
}

// MARK: Metric pages

/// Large chart with its current value and min / average / max.
private struct ChartCard: View {
    let title: String
    let symbol: String
    let tint: Color
    var trailing: String?
    let value: String
    var unit = ""
    let times: Ring<Date>
    let series: [ChartSeries]
    var domain: ClosedRange<Double>?
    let axis: (Double) -> String

    var body: some View {
        DashCard(title: title, symbol: symbol, tint: tint, trailing: trailing) {
            BigValue(value: value, unit: unit)
            HistoryChart(times: times, series: series, domain: domain, height: 210, axis: axis)
            if let lead = series.first { RangeStats(times: times, values: lead.values, format: { axis($0 / lead.scale) }) }
        }
    }
}

private struct TopApps: View {
    let title: String
    let apps: [AppUsage]

    var body: some View {
        DashCard(title: title, symbol: "square.grid.2x2", tint: .signal) {
            VStack(spacing: 0) {
                ForEach(apps) { app in
                    HStack(spacing: 8) {
                        if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                        Text(app.name).lineLimit(1)
                        Spacer()
                        Text(Fmt.memory(app.memory)).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                        Text(Fmt.percent(app.cpu, decimals: 1)).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
                    }
                    .monospacedDigit()
                    .padding(.vertical, 5)
                    Divider().opacity(app.id == apps.last?.id ? 0 : 1)
                }
            }
        }
    }
}

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

private struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 7))
            configuration.title.foregroundStyle(.secondary)
        }
    }
}

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

func keyValue(_ key: String, _ value: String, dot: Color? = nil) -> some View {
    VStack(spacing: 0) {
        HStack {
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .padding(.vertical, 6)
        Divider()
    }
}

struct DiskPage: View {
    let monitor: Monitor
    @Bindable private var nav = DashboardNavigation.shared

    var body: some View {
        let m = monitor
        let used = m.diskTotal - m.diskFree
        // The tabs scroll with the page, so the toolbar looks and behaves like every other page's.
        page {
            HStack {
                Picker("Show", selection: $nav.diskCleanUp) {
                    Text("Usage").tag(false)
                    Text("Clean Up").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            if nav.diskCleanUp {
                CleanUpCard()
            } else {
                usage(m, used: used)
            }
        }
    }

    @ViewBuilder private func usage(_ m: Monitor, used: Int64) -> some View {
        DashCard(title: "Macintosh HD", symbol: "internaldrive", tint: .orange, trailing: "startup disk") {
            BigValue(value: Fmt.storage(m.diskFree), caption: "available")
            UsageBar(fraction: m.diskTotal > 0 ? Double(used) / Double(m.diskTotal) : 0, color: .orange)
            LazyVGrid(columns: two, spacing: 0) {
                keyValue("Used", Fmt.storage(used))
                keyValue("Capacity", Fmt.storage(m.diskTotal))
            }
        }
        DashCard(title: "Activity", symbol: "arrow.up.arrow.down", tint: .orange, trailing: "all disks") {
            HStack(spacing: 24) {
                BigValue(value: Fmt.rate(m.diskRead), caption: "Read", dot: .orange)
                BigValue(value: Fmt.rate(m.diskWrite), caption: "Write", dot: .blue)
            }
            HistoryChart(
                times: m.times,
                series: [
                    ChartSeries(name: "Read", values: m.diskReadHistory, color: .orange),
                    ChartSeries(name: "Write", values: m.diskWriteHistory, color: .blue),
                ],
                height: 210, axis: { Fmt.rate($0) })
        }
    }
}

struct NetworkPage: View {
    let monitor: Monitor
    @State private var interfaces = NetworkInterface.all()

    var body: some View {
        let m = monitor
        page {
            DashCard(title: "Throughput", symbol: "network", tint: .green) {
                HStack(spacing: 24) {
                    BigValue(value: Fmt.rate(m.down), caption: "Download", dot: .green)
                    BigValue(value: Fmt.rate(m.up), caption: "Upload", dot: .teal)
                }
                HistoryChart(
                    times: m.times,
                    series: [
                        ChartSeries(name: "Down", values: m.downHistory, color: .green),
                        ChartSeries(name: "Up", values: m.upHistory, color: .teal),
                    ],
                    height: 210, axis: { Fmt.rate($0) })
                RangeStats(times: m.times, values: m.downHistory, format: { Fmt.rate($0) })
            }
            LazyVGrid(columns: two, spacing: 14) {
                DashCard(title: "Interfaces", symbol: "point.3.connected.trianglepath.dotted", tint: .green) {
                    VStack(spacing: 0) {
                        ForEach(interfaces, id: \.bsd) { i in
                            keyValue("\(i.name) (\(i.bsd))", i.address ?? "Not connected", dot: i.address == nil ? .secondary : .green)
                        }
                    }
                }
                DashCard(title: "Since boot", symbol: "clock.arrow.circlepath", tint: .green) {
                    VStack(spacing: 0) {
                        keyValue("Downloaded", Fmt.storage(m.networkTotal.down))
                        keyValue("Uploaded", Fmt.storage(m.networkTotal.up))
                    }
                }
            }
        }
        .onAppear { interfaces = NetworkInterface.all() }
    }
}

struct SensorsPage: View {
    let sensors: [Sensor]

    var body: some View {
        List {
            ForEach(Sensor.groupOrder, id: \.self) { group in
                let rows = sensors.filter { $0.group == group }
                if !rows.isEmpty {
                    Section(group) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, sensor in
                            HStack(spacing: 12) {
                                Text("\(group) \(i + 1)")
                                Text(sensor.id).font(.caption.monospaced()).foregroundStyle(.tertiary)
                                Spacer()
                                Sparkline(values: sensor.history, tint: .orange, maxValue: nil, window: 150).frame(width: 140, height: 20)
                                Text(TemperatureUnit.format(sensor.value, decimals: 1)).monospacedDigit().frame(
                                    width: 76, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if sensors.isEmpty { ContentUnavailableView("No temperature sensors found", systemImage: "thermometer.medium.slash") }
        }
    }
}

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
