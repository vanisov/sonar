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

        Window("Sonar", id: "dashboard") {
            DashboardView(monitor: monitor)
        }
        .defaultSize(width: 980, height: 700)
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

    @MainActor func text(_ m: Monitor) -> Text? {
        switch self {
        case .cpu: Text("\(Int(m.cpu.rounded()))%")
        case .cpuTemp: m.cpuTemp.map { Text("\(Int($0.rounded()))°") }
        case .gpuTemp: m.gpuTemp.map { Text("\(Image(systemName: "square.stack.3d.up"))\(Int($0.rounded()))°") }
        case .memory: Text("\(Image(systemName: "memorychip"))\(Int(m.memoryPercent.rounded()))%")
        case .network: Text("↓\(PanelView.bytes(m.down, .file))/s")
        case .fan: m.fanRPMs.max().map { Text("\(Image(systemName: "fan"))\(String(Int($0)))") }
        }
    }
}

private struct MenuBarLabel: View {
    let monitor: Monitor
    @AppStorage(MenuBarItem.storageKey) private var items = MenuBarItem.defaults

    var body: some View {
        let enabled = items.split(separator: ",")
        let parts = MenuBarItem.allCases.filter { enabled.contains(Substring($0.rawValue)) }.compactMap { $0.text(monitor) }
        let text = parts.reduce(Text(Image(systemName: "dot.radiowaves.left.and.right"))) { $0 + Text("  ") + $1 }
        Image(nsImage: Self.template(text.font(.system(size: 13)).monospacedDigit()))
    }

    /// Menu bar labels drop SF Symbols embedded in Text, so draw the label as a template image.
    /// Template images get tinted by macOS for light/dark menu bars.
    private static func template(_ view: some View) -> NSImage {
        let renderer = ImageRenderer(content: view.foregroundStyle(.black))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}
