import SwiftUI

@main
struct SonarApp: App {
    @State private var monitor = Monitor()
    @State private var showingSettings = false // lives here: MenuBarExtra rebuilds its content whenever the label changes

    init() {
        NSApplication.shared.setActivationPolicy(.accessory) // no Dock icon when run via `swift run`
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            snapshot(to: CommandLine.arguments[i + 1])
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(monitor: monitor, showingSettings: $showingSettings)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }

    /// Debug aid: `Sonar --snapshot panel.png` renders the popover after a few samples and quits.
    private func snapshot(to path: String) {
        let monitor = monitor
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            let renderer = ImageRenderer(content: PanelView(monitor: monitor, showingSettings: .constant(false))
                .background(Color(white: 0.13))
                .environment(\.colorScheme, .dark))
            renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            print("sensors:", monitor.sensors.map { "\($0.id)=\(Int($0.value))" }.joined(separator: " "))
            print("fans:", monitor.fanRPMs, "gpu:", monitor.gpu, "apps:", monitor.apps.count, "cpuTemp:", monitor.cpuTemp ?? 0, "gpuTemp:", monitor.gpuTemp ?? 0)
            exit(0)
        }
    }
}

enum MenuBarItem: String, CaseIterable {
    case cpu, cpuTemp, gpuTemp, memory, network, fan

    static let storageKey = "menuBarItems"
    static let defaults = "cpu,cpuTemp"

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

    /// What to draw: an optional SF Symbol and the value.
    @MainActor func part(_ m: Monitor) -> (symbol: String?, value: String)? {
        switch self {
        case .cpu: (nil, "\(Int(m.cpu.rounded()))%")
        case .cpuTemp: m.cpuTemp.map { (nil, "\(Int($0.rounded()))°") }
        case .gpuTemp: m.gpuTemp.map { ("square.stack.3d.up", "\(Int($0.rounded()))°") }
        case .memory: ("memorychip", "\(Int(m.memoryPercent.rounded()))%")
        case .network: (nil, "↓\(PanelView.bytes(m.down, .file))/s")
        case .fan: m.fanRPMs.max().map { ("fan", String(Int($0))) }
        }
    }
}

private struct MenuBarLabel: View {
    let monitor: Monitor
    @AppStorage(MenuBarItem.storageKey) private var items = MenuBarItem.defaults

    private static var cached: (key: String, image: NSImage)?

    var body: some View {
        let enabled = items.split(separator: ",")
        let parts = MenuBarItem.allCases.filter { enabled.contains(Substring($0.rawValue)) }.compactMap { $0.part(monitor) }
        // Values usually round to the same text between samples; only redraw when it actually changes.
        let key = parts.map { ($0.symbol ?? "") + $0.value }.joined(separator: " ")
        if Self.cached?.key != key { Self.cached = (key, Self.template(parts)) }
        return Image(nsImage: Self.cached!.image)
    }

    /// Menu bar labels drop SF Symbols embedded in Text, so draw the label ourselves as a template image
    /// (macOS tints templates for light/dark menu bars). Plain AppKit text drawing: SwiftUI's ImageRenderer
    /// spun up ~115 MB of GPU memory on every redraw.
    private static func template(_ parts: [(symbol: String?, value: String)]) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let text = NSMutableAttributedString()
        func symbol(_ name: String) {
            let attachment = NSTextAttachment()
            attachment.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
            text.append(NSAttributedString(attachment: attachment))
        }
        symbol("dot.radiowaves.left.and.right")
        for part in parts {
            text.append(NSAttributedString(string: "  "))
            if let name = part.symbol { symbol(name) }
            text.append(NSAttributedString(string: part.value))
        }
        text.addAttributes([.font: font, .foregroundColor: NSColor.black], range: NSRange(location: 0, length: text.length))
        let size = text.size()
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { rect in
            text.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }
}
