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
            snapshot(to: args[i + 1], seconds: i + 2 < args.count ? Int(args[i + 2]) ?? 5 : 5, clear: args.contains("--clear"))
        }
        #if DEBUG  // README screenshots only; --snapshot above stays in releases for bug reports
            if let i = args.firstIndex(of: "--snapshot-dashboard"), i + 1 < args.count {
                snapshotDashboard(to: args[i + 1], seconds: i + 2 < args.count ? Int(args[i + 2]) ?? 20 : 20)
            }
            if let i = args.firstIndex(of: "--open-dashboard"), i + 1 < args.count {
                openDashboardBehind(args[i + 1])
            }
        #endif
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

    #if DEBUG
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
                Self.writePNG(renderer, to: path)
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
    #endif

    /// Writes a rendered view as an 8-bit sRGB PNG. On an HDR display the renderer produces a BT.2100 PQ image,
    /// which looks washed out once saved, so it's redrawn into sRGB first.
    private static func writePNG<V: View>(_ renderer: ImageRenderer<V>, to path: String) {
        guard let image = renderer.cgImage, let srgb = CGColorSpace(name: CGColorSpace.sRGB),
            let ctx = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let converted = ctx.makeImage(), let png = NSBitmapImageRep(cgImage: converted).representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    /// Debug aid: `Sonar --snapshot panel.png [seconds] [--clear]` renders the panel after collecting that many
    /// seconds of samples (5 by default), prints the sensor readings, and quits. `--clear` leaves out the background,
    /// for placing the panel on a desktop image.
    private func snapshot(to path: String, seconds: Int, clear: Bool) {
        let monitor = monitor
        Task { @MainActor in
            monitor.viewAppeared()  // sample everything the panel shows, as when it's open
            try? await Task.sleep(for: .seconds(seconds))
            let renderer = ImageRenderer(
                content: PanelContent(monitor: monitor, interactive: false)
                    .background(clear ? Color.clear : Color(white: 0.13))
                    .environment(\.colorScheme, .dark))
            renderer.scale = 2
            Self.writePNG(renderer, to: path)
            print("sensors:", monitor.sensors.map { "\($0.id)=\(Int($0.value))" }.joined(separator: " "))
            print(
                "cpu:", Int(monitor.cpu.rounded()), "fans:", monitor.fanRPMs, "gpu:", monitor.gpu, "apps:", monitor.apps.count, "cpuTemp:",
                monitor.cpuTemp ?? 0, "gpuTemp:",
                monitor.gpuTemp ?? 0)
            exit(0)
        }
    }
}
