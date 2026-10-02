import SwiftUI

/// The panel itself, without the visibility handling (also used by `--snapshot`).
struct PanelContent: View {
    let monitor: Monitor
    var openDashboard: (DashboardSection?) -> Void = { _ in }
    var openSettings: () -> Void = {}
    @AppStorage(Prefs.panelCards) private var cardsRaw = PanelCard.defaults
    @AppStorage(Prefs.panelTopApps) private var topApps = 5
    @AppStorage(Prefs.panelSparkline) private var sparkline = 60
    @AppStorage(Prefs.panelCardClick) private var cardOpens = true
    @AppStorage(TemperatureUnit.storageKey) private var unit = TemperatureUnit.system.rawValue
    @AppStorage(Prefs.storageBinary) private var binary = false
    @AppStorage(Prefs.networkBits) private var bits = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Chip(text: monitor.chip)
                Chip(text: Fmt.memory(monitor.memoryTotal))
                Chip(text: monitor.osVersion)
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    if row == [.apps] {
                        GridRow { card(.apps).gridCellColumns(2) }
                    } else {
                        GridRow {
                            ForEach(row) { card($0) }
                            if row.count == 1 { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                        }
                    }
                }
            }
            footer
        }
        .padding(16)
        .frame(width: 380)
    }

    /// Metric cards pair up two per row; Top apps always takes a full row.
    private var rows: [[PanelCard]] {
        var rows: [[PanelCard]] = []
        var pending: [PanelCard] = []
        for card in PanelCard.enabled {
            if card == .apps {
                if !pending.isEmpty { rows.append(pending) }
                pending = []
                rows.append([.apps])
            } else {
                pending.append(card)
                if pending.count == 2 {
                    rows.append(pending)
                    pending = []
                }
            }
        }
        if !pending.isEmpty { rows.append(pending) }
        return rows
    }

    @ViewBuilder private func card(_ card: PanelCard) -> some View {
        let content = Group {
            switch card {
            case .cpu: cpu
            case .gpu: gpu
            case .memory: memory
            case .disk: disk
            case .network: network
            case .fans: fans
            case .apps: TopAppsCard(apps: Array(monitor.apps.prefix(topApps)))
            }
        }
        if cardOpens {
            Button {
                openDashboard(card.section)
            } label: {
                content
            }.buttonStyle(CardButtonStyle())
        } else {
            content
        }
    }

    private var window: String { sparkline >= 150 ? "5 min" : sparkline <= 30 ? "1 min" : "2 min" }

    private var cpu: some View {
        MetricCard(
            title: "CPU", symbol: "cpu", tint: .blue, badge: monitor.cpuTemp.map { TemperatureUnit.format($0) },
            value: monitor.cpu.formatted(.number.precision(.fractionLength(1))), unit: "%",
            footer: "\(monitor.cores) logical cores · \(window)"
        ) {
            Sparkline(values: monitor.cpuHistory, tint: .blue, window: sparkline)
        }
    }

    private var gpu: some View {
        MetricCard(
            title: "GPU", symbol: "square.stack.3d.up", tint: .pink, badge: monitor.gpuTemp.map { TemperatureUnit.format($0) },
            value: "\(Int(monitor.gpu))", unit: "%", footer: "Device activity · \(window)"
        ) {
            Sparkline(values: monitor.gpuHistory, tint: .pink, window: sparkline)
        }
    }

    private var memory: some View {
        MetricCard(
            title: "Memory", symbol: "memorychip", tint: .purple, badge: monitor.pressure,
            value: monitor.memoryPercent.formatted(.number.precision(.fractionLength(1))), unit: "%",
            footer: "\(Fmt.memory(monitor.memoryUsed)) / \(Fmt.memory(monitor.memoryTotal))"
        ) {
            Sparkline(values: monitor.memoryHistory, tint: .purple, window: sparkline)
        }
    }

    private var disk: some View {
        let used = monitor.diskTotal - monitor.diskFree
        let fraction = monitor.diskTotal > 0 ? Double(used) / Double(monitor.diskTotal) : 0
        let (value, unit) = Fmt.split(Fmt.storage(monitor.diskFree))
        return MetricCard(
            title: "Disk", symbol: "internaldrive", tint: .orange, badge: Fmt.storage(monitor.diskTotal),
            value: value, unit: "\(unit) free",
            footer: "\(Fmt.storage(used)) used · \(Int(fraction * 100))%"
        ) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule().fill(.orange.gradient).frame(width: g.size.width * fraction)
                }
            }
            .frame(height: 7)
        }
    }

    private var network: some View {
        let (value, unit) = Fmt.split(Fmt.rate(monitor.down))
        return MetricCard(
            title: "Network", symbol: "network", tint: .green, badge: "↓ / ↑",
            value: value, unit: unit,
            footer: "↓ Download · ↑ \(Fmt.rate(monitor.up))"
        ) {
            Sparkline(values: monitor.downHistory, tint: .green, maxValue: nil, window: sparkline)
        }
    }

    private var fans: some View {
        let fastest = monitor.fanRPMs.max()
        return MetricCard(
            title: "Fans", symbol: "fan", tint: .teal,
            badge: fastest == nil ? nil : (monitor.fansAuto ? "Auto" : "Manual"),
            value: fastest.map { "\(Int($0))" } ?? "—", unit: fastest == nil ? "" : "RPM",
            footer: fastest == nil ? "No fans found" : "Fastest of \(monitor.fanRPMs.count) fan\(monitor.fanRPMs.count == 1 ? "" : "s")"
        ) {
            Text(fastest == nil ? "Passively cooled" : monitor.fansAuto ? "Managed by macOS" : "Manually controlled")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Button {
                openDashboard(nil)
            } label: {
                Label("Open dashboard", systemImage: "square.grid.2x2")
            }
            Spacer()
            Button(action: openSettings) { Image(systemName: "slider.horizontal.3") }
                .help("Settings (⌘,)")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit Sonar")
        }
        .buttonStyle(HoverButtonStyle())
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, -8)  // align the hover highlight's text with the cards above
    }
}
