import SwiftUI

struct PanelView: View {
    let monitor: Monitor
    @Binding var showingSettings: Bool
    @State private var visible = false
    @State private var size = CGSize(width: 380, height: 740)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            // MenuBarExtra keeps a closed popover alive offscreen. Rendering nothing while closed stops it
            // observing Monitor; otherwise every sample re-rendered it and animations never settled (~20% CPU).
            if !visible {
                Color.clear.frame(width: size.width, height: size.height)
            } else if showingSettings {
                SettingsView { showingSettings = false }
            } else {
                PanelContent(
                    monitor: monitor,
                    openDashboard: { section in
                        dismiss()  // a new key window doesn't close the popover on its own
                        DashboardWindow.show(monitor, section: section)
                    },
                    openSettings: { showingSettings = true }
                )
                .background(
                    GeometryReader { g in
                        Color.clear.onAppear { size = g.size }.onChange(of: g.size) { _, new in size = new }
                    })
            }
        }
        .onAppear {
            visible = true
            monitor.viewAppeared()
        }
        .onDisappear {
            visible = false
            monitor.viewDisappeared()
        }
    }
}

/// The panel itself, without the visibility handling (also used by `--snapshot`).
struct PanelContent: View {
    let monitor: Monitor
    var openDashboard: (DashboardView.Section) -> Void = { _ in }
    var openSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Chip(text: monitor.chip)
                Chip(text: Int64(monitor.memoryTotal).formatted(.byteCount(style: .memory)))
                Chip(text: monitor.osVersion)
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    card(.overview) { cpu }
                    card(.overview) { gpu }
                }
                GridRow {
                    card(.overview) { memory }
                    card(.overview) { disk }
                }
                GridRow {
                    card(.overview) { network }
                    card(.sensors) { fans }
                }
            }
            card(.apps) { TopAppsCard(apps: Array(monitor.apps.prefix(5))) }
            footer
        }
        .padding(16)
        .frame(width: 380)
    }

    private func card(_ section: DashboardView.Section, @ViewBuilder content: () -> some View) -> some View {
        Button {
            openDashboard(section)
        } label: {
            content()
        }
        .buttonStyle(CardButtonStyle())
    }

    private var cpu: some View {
        MetricCard(
            title: "CPU", symbol: "cpu", tint: .blue, badge: monitor.cpuTemp.map { TemperatureUnit.format($0) },
            value: monitor.cpu.formatted(.number.precision(.fractionLength(1))), unit: "%",
            footer: "\(monitor.cores) logical cores · 2 min"
        ) {
            Sparkline(values: monitor.cpuHistory, tint: .blue)
        }
    }

    private var gpu: some View {
        MetricCard(
            title: "GPU", symbol: "square.stack.3d.up", tint: .pink, badge: monitor.gpuTemp.map { TemperatureUnit.format($0) },
            value: "\(Int(monitor.gpu))", unit: "%", footer: "Device activity · 2 min"
        ) {
            Sparkline(values: monitor.gpuHistory, tint: .pink)
        }
    }

    private var memory: some View {
        MetricCard(
            title: "Memory", symbol: "memorychip", tint: .purple, badge: monitor.pressure,
            value: monitor.memoryPercent.formatted(.number.precision(.fractionLength(1))), unit: "%",
            footer: "\(PanelView.bytes(monitor.memoryUsed, .memory)) / \(PanelView.bytes(monitor.memoryTotal, .memory))"
        ) {
            Sparkline(values: monitor.memoryHistory, tint: .purple)
        }
    }

    private var disk: some View {
        let used = monitor.diskTotal - monitor.diskFree
        let fraction = monitor.diskTotal > 0 ? Double(used) / Double(monitor.diskTotal) : 0
        let (value, unit) = PanelView.split(PanelView.bytes(monitor.diskFree, .file))
        return MetricCard(
            title: "Disk", symbol: "internaldrive", tint: .orange, badge: PanelView.bytes(monitor.diskTotal, .file),
            value: value, unit: "\(unit) free",
            footer: "\(PanelView.bytes(used, .file)) used · \(Int(fraction * 100))%"
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
        let (value, unit) = PanelView.split(PanelView.bytes(monitor.down, .file))
        return MetricCard(
            title: "Network", symbol: "network", tint: .green, badge: "↓ / ↑",
            value: value, unit: "\(unit)/s",
            footer: "↓ Download · ↑ \(PanelView.bytes(monitor.up, .file))/s"
        ) {
            Sparkline(values: monitor.downHistory, tint: .green, maxValue: nil)
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
                openDashboard(.overview)
            } label: {
                Label("Open dashboard", systemImage: "square.grid.2x2")
            }
            Spacer()
            Button(action: openSettings) { Image(systemName: "slider.horizontal.3") }
                .help("Settings")
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

extension PanelView {
    // MARK: Formatting

    static func bytes<T: BinaryInteger>(_ v: T, _ style: ByteCountFormatStyle.Style) -> String {
        Int64(v).formatted(.byteCount(style: style, spellsOutZero: false))
    }

    static func bytes(_ v: Double, _ style: ByteCountFormatStyle.Style) -> String { bytes(Int64(max(v, 0)), style) }

    /// "293.11 GB" -> ("293.11", "GB")
    static func split(_ s: String) -> (String, String) {
        let parts = s.split(whereSeparator: \.isWhitespace)
        return (String(parts.first ?? ""), parts.dropFirst().joined(separator: " "))
    }

}

// MARK: Components

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.07)))
    }
}

/// Plain button with a hover highlight, so it reads as clickable.
struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }

    private struct Styled: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8).padding(.vertical, 5)
                .foregroundStyle(hovering ? .primary : .secondary)
                .background(
                    .primary.opacity(configuration.isPressed ? 0.14 : hovering ? 0.08 : 0),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .onHover { hovering = $0 }
        }
    }
}

/// A whole card as a button: lightens on hover, darkens while pressed.
private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }

    private struct Styled: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(configuration.isPressed ? 0.07 : hovering ? 0.035 : 0))
                        .allowsHitTesting(false)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onHover { hovering = $0 }
        }
    }
}

private struct MetricCard<Visual: View>: View {
    let title: String, symbol: String, tint: Color
    var badge: String?
    let value: String, unit: String, footer: String
    @ViewBuilder var visual: Visual

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.primary.opacity(0.07), in: Capsule())
                }
            }
            .font(.system(size: 12, weight: .semibold))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
            .lineLimit(1)

            visual.frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .leading)

            Text(footer).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .modifier(CardBackground())
    }
}

/// Filled sparkline drawn as a plain path; much cheaper to redraw than a Swift Charts chart.
struct Sparkline: View {
    let values: Ring<Float>, tint: Color
    var maxValue: Float? = 100
    var window = 60  // samples shown: 2 min

    var body: some View {
        let shown = Array(values.suffix(window))
        let top = maxValue ?? max(shown.max() ?? 1, 1)
        ZStack {
            SparklineShape(values: shown, window: window, top: top, closed: true)
                .fill(LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
            SparklineShape(values: shown, window: window, top: top, closed: false)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct SparklineShape: Shape {
    let values: [Float], window: Int, top: Float, closed: Bool

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let r = rect.insetBy(dx: 0, dy: 1)  // keep the stroke inside at 0% and 100%
        let step = r.width / CGFloat(window - 1)
        let x0 = r.minX + CGFloat(window - values.count) * step  // right-aligned: fresh history grows in from the right
        let points = values.enumerated().map { i, v in
            CGPoint(x: x0 + CGFloat(i) * step, y: r.maxY - CGFloat(min(max(v / top, 0), 1)) * r.height)
        }
        var path = Path()
        path.move(to: points[0])
        // Curve through midpoints for a smooth line without overshoot.
        for i in 1..<points.count {
            let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
            path.addQuadCurve(to: mid, control: points[i - 1])
        }
        path.addLine(to: points[points.count - 1])
        if closed {
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: rect.maxY))
            path.addLine(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct TopAppsCard: View {
    let apps: [AppUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Top apps", systemImage: "chart.bar.fill").labelStyle(TintedIcon(tint: .indigo))
                Spacer()
                Text("Memory").frame(width: 72, alignment: .trailing)
                Text("CPU").frame(width: 46, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

            ForEach(apps) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                    Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Text(PanelView.bytes(app.memory, .memory)).frame(width: 72, alignment: .trailing)
                    Text(app.cpu.formatted(.number.precision(.fractionLength(1))) + "%").frame(width: 46, alignment: .trailing)
                }
                .font(.system(size: 12))
                .monospacedDigit()
            }

            Text("CPU is a share of the whole Mac").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .modifier(CardBackground())
    }
}

private struct TintedIcon: LabelStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(tint); configuration.title
        }
    }
}
