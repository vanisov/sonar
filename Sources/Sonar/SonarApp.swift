import SwiftUI

@main
struct SonarApp: App {
    private let monitor = Monitor()  // lives as long as the app

    init() {
        DashboardWindow.monitor = monitor
        NSApplication.shared.setActivationPolicy(.accessory)  // no Dock icon when run via `swift run`
        Appearance(rawValue: Prefs.string(Prefs.appearance, default: "system"))?.apply()
        Hotkeys.reload()
        Updater.shared.startAutomaticChecks()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            snapshot(to: args[i + 1])
        }
        if let i = args.firstIndex(of: "--snapshot-dashboard"), i + 1 < args.count {
            snapshotDashboard(to: args[i + 1], seconds: i + 2 < args.count ? Int(args[i + 2]) ?? 20 : 20)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { SettingsWindow.open() }.keyboardShortcut(",")
            }
        }
    }

    /// Debug aid: `Sonar --snapshot-dashboard charts.png [seconds]` renders the dashboard's CPU and network charts
    /// offscreen after collecting that many seconds of samples, then quits. No windows open and no input is needed.
    /// (Charts only: ImageRenderer can't draw the pages' scroll views.)
    private func snapshotDashboard(to path: String, seconds: Int) {
        let monitor = monitor
        Task { @MainActor in
            monitor.viewAppeared()
            try? await Task.sleep(for: .seconds(seconds))
            let renderer = ImageRenderer(
                content: VStack(spacing: 24) {
                    HistoryChart(
                        times: monitor.times, series: [ChartSeries(name: "CPU", values: monitor.cpuHistory, color: .blue)],
                        domain: 0...100, height: 180, axis: { Fmt.percent($0) })
                    HistoryChart(
                        times: monitor.times, series: [ChartSeries(name: "Down", values: monitor.downHistory, color: .green)],
                        height: 180, axis: { Fmt.rate($0) })
                }
                .padding(24)
                .frame(width: 520)
                .background(Color(white: 0.13))
                .environment(\.colorScheme, .dark))
            renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation,
                let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            exit(0)
        }
    }

    /// Debug aid: `Sonar --snapshot panel.png` renders the popover after a few samples and quits.
    private func snapshot(to path: String) {
        let monitor = monitor
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            let renderer = ImageRenderer(
                content: PanelContent(monitor: monitor)
                    .background(Color(white: 0.13))
                    .environment(\.colorScheme, .dark))
            renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation,
                let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            print("sensors:", monitor.sensors.map { "\($0.id)=\(Int($0.value))" }.joined(separator: " "))
            print(
                "fans:", monitor.fanRPMs, "gpu:", monitor.gpu, "apps:", monitor.apps.count, "cpuTemp:", monitor.cpuTemp ?? 0, "gpuTemp:",
                monitor.gpuTemp ?? 0)
            exit(0)
        }
    }
}

enum MenuBarItem: String, CaseIterable, Identifiable {
    case cpu, cpuTemp, gpuTemp, memory, network, fan

    static let storageKey = "menuBarItems"
    static let defaults = "cpu,cpuTemp"

    enum Style: String, CaseIterable {
        case iconAndValue = "both", value, icon

        var title: String {
            switch self {
            case .iconAndValue: "Icon and value"
            case .value: "Value only"
            case .icon: "Icon only"
            }
        }
    }

    /// One stat as drawn: an optional SF Symbol, an optional value, and how urgent it is (0 normal, 1 warm, 2 hot).
    struct Part {
        var symbol: String?
        var value: String?
        var level = 0
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU usage"
        case .cpuTemp: "CPU temperature"
        case .gpuTemp: "GPU temperature"
        case .memory: "Memory"
        case .network: "Network download"
        case .fan: "Fan speed"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .cpuTemp: "thermometer.medium"
        case .gpuTemp: "square.stack.3d.up"
        case .memory: "memorychip"
        case .network: "arrow.down"
        case .fan: "fan"
        }
    }

    @MainActor func part(_ m: Monitor, decimals: Int) -> Part? {
        func number(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(decimals))) }
        func level(_ v: Double, warm: Double, hot: Double) -> Int { v >= hot ? 2 : v >= warm ? 1 : 0 }
        func degrees(_ c: Double) -> Part { Part(value: number(TemperatureUnit.convert(c)) + "°", level: level(c, warm: 90, hot: 100)) }
        return switch self {
        case .cpu: Part(value: number(m.cpu) + "%", level: level(m.cpu, warm: 80, hot: 95))
        case .cpuTemp: m.cpuTemp.map(degrees)
        case .gpuTemp: m.gpuTemp.map(degrees)
        case .memory: Part(value: number(m.memoryPercent) + "%", level: m.pressure == "Critical" ? 2 : m.pressure == "Warning" ? 1 : 0)
        case .network: Part(value: Fmt.rate(m.down))
        case .fan: m.fanRPMs.max().map { Part(value: String(Int($0))) }
        }
    }

    /// Fixed example values for the Settings preview, so Settings never has to observe live data.
    var example: Part {
        switch self {
        case .cpu: Part(value: "34%")
        case .cpuTemp: Part(value: "\(Int(TemperatureUnit.convert(45).rounded()))°")
        case .gpuTemp: Part(value: "\(Int(TemperatureUnit.convert(40).rounded()))°")
        case .memory: Part(value: "67%")
        case .network: Part(value: Fmt.rate(4200))
        case .fan: Part(value: "1350")
        }
    }
}

/// Which menu bar stats show, in what order, and how.
@MainActor enum MenuBarConfig {
    static var order: [MenuBarItem] {
        let saved = Prefs.string(Prefs.menuBarOrder, default: "").split(separator: ",").compactMap { MenuBarItem(rawValue: String($0)) }
        return saved + MenuBarItem.allCases.filter { !saved.contains($0) }
    }

    static var enabled: Set<MenuBarItem> {
        Set(
            Prefs.string(Prefs.menuBarItems, default: MenuBarItem.defaults).split(separator: ",")
                .compactMap { MenuBarItem(rawValue: String($0)) })
    }

    static var styles: [MenuBarItem: MenuBarItem.Style] {
        var result: [MenuBarItem: MenuBarItem.Style] = [:]
        for pair in Prefs.string(Prefs.menuBarStyles, default: "").split(separator: ",") {
            let kv = pair.split(separator: "=")
            if kv.count == 2, let item = MenuBarItem(rawValue: String(kv[0])), let style = MenuBarItem.Style(rawValue: String(kv[1])) {
                result[item] = style
            }
        }
        return result
    }

    static func style(_ item: MenuBarItem) -> MenuBarItem.Style { styles[item] ?? .iconAndValue }

    /// Enabled stats in order, each with its style applied.
    static func parts(_ part: (MenuBarItem) -> MenuBarItem.Part?) -> [MenuBarItem.Part] {
        let on = enabled
        let styles = styles
        return order.filter { on.contains($0) }.compactMap { item in
            guard var p = part(item) else { return nil }
            let style = styles[item] ?? .iconAndValue
            if style != .value { p.symbol = item.symbol }
            if style == .icon { p.value = nil }
            if item == .network, style == .value, let v = p.value { p.value = "↓" + v }
            return p
        }
    }

    static func previewImage() -> NSImage {
        let parts = parts { $0.example }
        return parts.isEmpty ? MenuBarLogo.image : render(parts, highlight: false)
    }

    /// Draws the label with AppKit text drawing. Menu bar labels drop SF Symbols embedded in Text, and SwiftUI's
    /// ImageRenderer spun up ~115 MB of GPU memory on every redraw. A template image unless something is highlighted,
    /// in which case dynamic colors keep it right in light and dark menu bars.
    static func render(_ parts: [MenuBarItem.Part], highlight: Bool) -> NSImage {
        let colored = highlight && parts.contains { $0.level > 0 }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let text = NSMutableAttributedString()
        for (i, part) in parts.enumerated() {
            let color: NSColor =
                !colored ? .black : part.level == 2 ? .systemRed : part.level == 1 ? .systemOrange : .labelColor
            if i > 0 { text.append(NSAttributedString(string: "  ")) }
            if let name = part.symbol {
                let attachment = NSTextAttachment()
                var config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                if colored { config = config.applying(.init(paletteColors: [color])) }
                attachment.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                text.append(NSAttributedString(attachment: attachment))
                if part.value != nil { text.append(NSAttributedString(string: " ")) }
            }
            if let value = part.value {
                text.append(NSAttributedString(string: value, attributes: [.foregroundColor: color]))
            }
        }
        text.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.length))
        let size = text.size()
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { rect in
            text.draw(in: rect)
            return true
        }
        image.isTemplate = !colored
        return image
    }
}

private struct MenuBarLabel: View {
    let monitor: Monitor
    // Read so the label redraws when any of these change.
    @AppStorage(Prefs.menuBarItems) private var items = MenuBarItem.defaults
    @AppStorage(Prefs.menuBarOrder) private var order = ""
    @AppStorage(Prefs.menuBarStyles) private var styles = ""
    @AppStorage(Prefs.menuBarDecimals) private var decimals = 0
    @AppStorage(Prefs.menuBarHighlight) private var highlight = true
    @AppStorage(TemperatureUnit.storageKey) private var unit = TemperatureUnit.system.rawValue

    private static var cached: (key: String, image: NSImage)?

    var body: some View {
        let parts = MenuBarConfig.parts { $0.part(monitor, decimals: decimals) }
        // Values usually round to the same text between samples; only redraw when it actually changes.
        let key = parts.map { "\($0.symbol ?? "")\($0.value ?? "")\($0.level)" }.joined(separator: " ") + "\(highlight)"
        if Self.cached?.key != key {
            Self.cached = (key, parts.isEmpty ? MenuBarLogo.image : MenuBarConfig.render(parts, highlight: highlight))
        }
        return Image(nsImage: Self.cached!.image)
    }
}
