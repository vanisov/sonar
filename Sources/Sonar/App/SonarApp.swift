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
        if let i = args.firstIndex(of: "--open-dashboard"), i + 1 < args.count {
            openDashboardBehind(args[i + 1])
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

    /// Debug aid for README screenshots: `Sonar --open-dashboard disk` opens the dashboard behind every other window
    /// without taking focus and prints its window number, for `screencapture -l <number>`. Add `--scan` to open Disk's
    /// Clean Up tab and start a scan.
    private func openDashboardBehind(_ section: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            DashboardNavigation.shared.diskCleanUp = CommandLine.arguments.contains("--scan")  // Disk → Clean Up, scanning
            DashboardWindow.show(DashboardSection(rawValue: section) ?? .overview, activate: false)
            print("window", DashboardWindow.windowNumber ?? 0)
            fflush(stdout)
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
