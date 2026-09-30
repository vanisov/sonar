import Charts
import SwiftUI

/// Created on demand and torn down on close. A SwiftUI `Window` scene stays alive offscreen
/// and kept redrawing its hour-long charts while hidden.
@MainActor enum DashboardWindow {
    private static var window: NSWindow?

    static func show(_ monitor: Monitor) {
        if window == nil {
            let host = NSHostingController(rootView: DashboardView(monitor: monitor))
            host.sceneBridgingOptions = .all  // lets the split view install its sidebar toolbar
            let w = NSWindow(contentViewController: host)
            w.title = "Sonar"
            w.styleMask.insert(.fullSizeContentView)
            w.setContentSize(NSSize(width: 980, height: 700))
            w.isReleasedWhenClosed = false
            w.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { note in
                MainActor.assumeIsolated {
                    // AppKit can keep a closed window around; detach the SwiftUI tree so it stops updating.
                    (note.object as? NSWindow)?.contentViewController = nil
                    window = nil
                }
            }
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct DashboardView: View {
    let monitor: Monitor
    @State private var section: Section? = .overview

    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview", sensors = "Sensors", apps = "Apps"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .overview: "chart.xyaxis.line"
            case .sensors: "thermometer.medium"
            case .apps: "square.stack"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { s in
                Label(s.rawValue, systemImage: s.symbol).tag(s)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            switch section ?? .overview {
            case .overview: OverviewView(monitor: monitor)
            case .sensors: SensorsView(sensors: monitor.sensors)
            case .apps: AppsTable(apps: monitor.apps)
            }
        }
        .onAppear(perform: monitor.viewAppeared)
        .onDisappear(perform: monitor.viewDisappeared)
    }
}

// MARK: Overview

private struct OverviewView: View {
    let monitor: Monitor

    var body: some View {
        let m = monitor
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                HistoryCard(
                    title: "CPU", symbol: "cpu", value: percent(m.cpu), times: m.times,
                    series: [("CPU", m.cpuHistory, .blue)], domain: 0...100, axis: percent)
                HistoryCard(
                    title: "GPU", symbol: "square.stack.3d.up", value: percent(m.gpu), times: m.times,
                    series: [("GPU", m.gpuHistory, .pink)], domain: 0...100, axis: percent)
                HistoryCard(
                    title: "Memory", symbol: "memorychip", value: percent(m.memoryPercent), times: m.times,
                    series: [("Memory", m.memoryHistory, .purple)], domain: 0...100, axis: percent)
                HistoryCard(
                    title: "Network", symbol: "network",
                    value: "↓ \(rate(m.down))  ↑ \(rate(m.up))", times: m.times,
                    series: [("Download", m.downHistory, .green), ("Upload", m.upHistory, .teal)], axis: rate)
                if let t = m.cpuTemp {
                    HistoryCard(
                        title: "CPU temperature", symbol: "thermometer.medium", value: degrees(t), times: m.times,
                        series: [("CPU", m.cpuTempHistory, .orange)], axis: degrees)
                }
                if let t = m.gpuTemp {
                    HistoryCard(
                        title: "GPU temperature", symbol: "thermometer.medium", value: degrees(t), times: m.times,
                        series: [("GPU", m.gpuTempHistory, .red)], axis: degrees)
                }
            }
            .padding(20)
        }
        .navigationTitle("Last hour")
    }

    private func percent(_ v: Double) -> String { "\(Int(v.rounded()))%" }
    private func rate(_ v: Double) -> String { "\(PanelView.bytes(v, .file))/s" }
    private func degrees(_ v: Double) -> String { "\(Int(v.rounded())) °C" }
}

private struct HistoryCard: View {
    let title: String, symbol: String, value: String
    let times: Ring<Date>
    let series: [(name: String, values: Ring<Float>, color: Color)]
    var domain: ClosedRange<Double>?
    let axis: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            Chart {
                ForEach(series, id: \.name) { s in
                    ForEach(0..<min(times.count, s.values.count), id: \.self) { i in
                        LineMark(x: .value("Time", times[i]), y: .value("Value", s.values[i]), series: .value("Series", s.name))
                            .foregroundStyle(s.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        if series.count == 1 {
                            AreaMark(x: .value("Time", times[i]), y: .value("Value", s.values[i]))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [s.color.opacity(0.25), s.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        }
                    }
                }
            }
            .chartYScale(domain: domain ?? 0...max(Double(series.compactMap { $0.values.max() }.max() ?? 1), 1))
            .chartXScale(domain: (times.last ?? .now).addingTimeInterval(-3600)...(times.last ?? .now))
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute, count: 10)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine()
                    AxisValueLabel { if let d = v.as(Double.self) { Text(axis(d)) } }
                }
            }
            .frame(height: 150)
        }
        .modifier(CardBackground())
    }
}

// MARK: Sensors

private struct SensorsView: View {
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
                                Text(sensor.id).font(.system(size: 11).monospaced()).foregroundStyle(.tertiary)
                                Spacer()
                                Sparkline(values: sensor.history, tint: .orange, maxValue: nil, window: 150)
                                    .frame(width: 140, height: 20)
                                Text("\(sensor.value.formatted(.number.precision(.fractionLength(1)))) °C")
                                    .monospacedDigit()
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if sensors.isEmpty { ContentUnavailableView("No temperature sensors found", systemImage: "thermometer.medium.slash") }
        }
        .navigationTitle("Sensors")
        .navigationSubtitle("SMC codes aren't documented by Apple, so grouping is approximate")
    }
}

// MARK: Apps

private struct AppsTable: View {
    let apps: [AppUsage]
    @State private var order = [KeyPathComparator(\AppUsage.memory, order: .reverse)]

    var body: some View {
        Table(apps.sorted(using: order), sortOrder: $order) {
            TableColumn("App", value: \.name) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                    Text(app.name)
                }
            }
            TableColumn("Memory", value: \.memory) { app in
                Text(PanelView.bytes(app.memory, .memory)).monospacedDigit()
            }
            .width(110)
            TableColumn("CPU", value: \.cpu) { app in
                Text(app.cpu.formatted(.number.precision(.fractionLength(1))) + "%").monospacedDigit()
            }
            .width(80)
        }
        .navigationTitle("Apps")
        .navigationSubtitle("\(apps.count) running · CPU is a share of the whole Mac")
    }
}
