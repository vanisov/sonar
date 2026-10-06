import SwiftUI

/// The panel itself, without the visibility handling (also used by `--snapshot`).
struct PanelContent: View {
    let monitor: Monitor
    var openDashboard: (DashboardSection?) -> Void = { _ in }
    var openSettings: () -> Void = {}
    var interactive = true  // false for snapshots: offscreen, buttons render as inactive
    @AppStorage(Prefs.panelCards) private var cardsRaw = PanelCard.defaults
    @AppStorage(Prefs.panelTopApps) private var topApps = 5
    @AppStorage(Prefs.panelSparkline) private var window = 60
    @AppStorage(Prefs.panelCardClick) private var cardOpens = true
    @AppStorage(TemperatureUnit.storageKey) private var unit = TemperatureUnit.system.rawValue
    @AppStorage(Prefs.storageBinary) private var binary = false
    @AppStorage(Prefs.networkBits) private var bits = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header.padding(.horizontal, 2).padding(.bottom, 4)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                if row.count == 2 {
                    HStack(spacing: 6) { ForEach(row) { card($0) } }.fixedSize(horizontal: false, vertical: true)
                } else if let only = row.first {
                    card(only)
                }
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 5) {
            (Text(Self.macName).fontWeight(.semibold) + Text(" · up \(Fmt.uptime(monitor.uptime))").foregroundColor(.secondary))
                .font(.system(size: 12)).lineLimit(1)
            Spacer(minLength: 8)
            Button {
                openDashboard(nil)
            } label: {
                Label("Open dashboard", systemImage: "square.grid.2x2")
            }
            .help("Open dashboard")
            Button(action: openSettings) { Label("Settings", systemImage: "slider.horizontal.3") }
                .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Sonar", systemImage: "power")
            }
            .buttonStyle(CircleButtonStyle(hoverTint: .signal))
            .help("Quit Sonar")
        }
        .buttonStyle(CircleButtonStyle())
    }

    /// "MacBook Pro (16-inch, Nov 2024)" → "MacBook Pro".
    private static let macName = MacInfo.shared.productName.components(separatedBy: " (").first ?? "Mac"

    // MARK: Layout

    /// Graph cards and Using the most take a full row; disk and fans pair up when they're next to each other.
    private var rows: [[PanelCard]] {
        var rows: [[PanelCard]] = []
        for card in PanelCard.enabled {
            if card.isCompact, let last = rows.last, last.count == 1, last[0].isCompact {
                rows[rows.count - 1].append(card)
            } else {
                rows.append([card])
            }
        }
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
            case .apps: AppsCard(apps: Array(monitor.apps.prefix(topApps)))
            }
        }
        if cardOpens && interactive {
            Button {
                openDashboard(card.section)
            } label: {
                content
            }.buttonStyle(CardButtonStyle())
        } else {
            content
        }
    }

    // MARK: Cards

    private var cpu: some View {
        GraphCard(title: "CPU", symbol: "cpu", tint: .blue) {
            ValueText(value: "\(Int(monitor.cpu.rounded()))", unit: "%")
        } trailing: {
            PeakLabel(values: monitor.cpuHistory, window: window)
            TemperaturePill(celsius: monitor.cpuTemp)
        } graph: {
            usageGraph(monitor.cpuHistory, temperature: monitor.cpuTempHistory, tint: .blue)
        }
    }

    private var gpu: some View {
        GraphCard(title: "GPU", symbol: "square.stack.3d.up", tint: .pink) {
            ValueText(value: "\(Int(monitor.gpu.rounded()))", unit: "%")
        } trailing: {
            PeakLabel(values: monitor.gpuHistory, window: window)
            TemperaturePill(celsius: monitor.gpuTemp)
        } graph: {
            usageGraph(monitor.gpuHistory, temperature: monitor.gpuTempHistory, tint: .pink)
        }
    }

    /// Usage columns with the temperature as a dashed line on the same 0–100 scale (20 °C at the bottom, 110 °C at
    /// the top). Both histories gain a sample every tick, so their indices match.
    private func usageGraph(_ usage: Ring<Float>, temperature: Ring<Float>, tint: Color) -> some View {
        ColumnGraph(
            values: usage, tint: tint, window: window, threshold: 80, overlay: temperature,
            overlayScale: { max($0 - 20, 0) / 90 * 100 }, markPeak: true,
            tooltip: { r in
                let i = r.upperBound - 1
                let t = i < temperature.count ? temperature[i] : 0
                let peak = r.map { usage[$0] }.max() ?? 0
                return "\(time(i)) · \(Int(peak.rounded()))%" + (t > 0 ? " · \(TemperatureUnit.format(Double(t)))" : "")
            })
    }

    private var memory: some View {
        let (used, usedUnit) = Fmt.split(Fmt.memory(monitor.memoryUsed))
        return GraphCard(title: "Memory", symbol: "memorychip", tint: .purple) {
            ValueText(value: used, unit: usedUnit, qualifier: "of \(Fmt.memory(monitor.memoryTotal))")
        } trailing: {
            Text("pressure \(monitor.pressure.lowercased())").font(.system(size: 11, weight: .medium))
                .foregroundStyle(monitor.pressure == "Normal" ? Color.secondary : Color.temperature)
        } graph: {
            ColumnGraph(
                values: monitor.memoryHistory, tint: .purple, window: window, threshold: 80,
                tooltip: { r in
                    let i = r.upperBound - 1
                    return "\(time(i)) · \(Fmt.memory(UInt64(Double(monitor.memoryHistory[i]) / 100 * Double(monitor.memoryTotal))))"
                })
        }
    }

    private var network: some View {
        let (down, downUnit) = Fmt.split(Fmt.rate(monitor.down))
        let (up, upUnit) = Fmt.split(Fmt.rate(monitor.up))
        return GraphCard(title: "Network", symbol: "network", tint: .green) {
            HStack(spacing: 10) {
                ValueText(value: "↓" + down, unit: downUnit)
                ValueText(value: "↑" + up, unit: upUnit)
            }
        } trailing: {
            Text("log scale").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        } graph: {
            MirrorColumnGraph(down: monitor.downHistory, up: monitor.upHistory, window: window) { r in
                let d = r.map { monitor.downHistory[$0] }.max() ?? 0, u = r.map { monitor.upHistory[$0] }.max() ?? 0
                return "\(time(r.upperBound - 1)) · ↓\(Fmt.rate(Double(d))) ↑\(Fmt.rate(Double(u)))"
            }
        }
    }

    private var disk: some View {
        let used = monitor.diskTotal - monitor.diskFree
        let (free, freeUnit) = Fmt.split(Fmt.storage(monitor.diskFree))
        return StatCard(
            title: "Disk", symbol: "internaldrive", tint: .orange,
            value: { ValueText(value: free, unit: "\(freeUnit) free", size: 20) },
            caption:
                "\(Int((Double(used) / Double(max(monitor.diskTotal, 1)) * 100).rounded()))% of \(Fmt.storage(monitor.diskTotal)) used",
            fraction: monitor.diskTotal > 0 ? Double(used) / Double(monitor.diskTotal) : 0)
    }

    private var fans: some View {
        let fastest = monitor.fanRPMs.max()
        let limit = monitor.fanLimits.map(\.max).max() ?? 0
        let caption =
            if fastest == nil { "Passively cooled" } else if !monitor.fansAuto { "Manually controlled" } else if (fastest ?? 0) < 1 {
                "macOS keeps them off"
            } else { "Cooling · max \(Int(limit)) rpm" }
        return StatCard(
            title: "Fans", symbol: "fan", tint: .teal,
            value: {
                if let fastest, fastest >= 1 {
                    ValueText(value: "\(Int(fastest))", unit: "rpm", size: 20)
                } else {
                    ValueText(value: fastest == nil ? "None" : "Off", size: 20)
                }
            },
            caption: caption,
            fraction: limit > 0 ? (fastest ?? 0) / limit : 0)
    }

    /// Clock time of a history sample.
    private func time(_ i: Int) -> String {
        guard i >= 0, i < monitor.times.count else { return "" }
        return monitor.times[i].formatted(date: .omitted, time: .standard)
    }

}
