import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable, Hashable {
    case overview, cpu, gpu, memory, disk, network, sensors, fans, apps, cleanUp, system

    static let metrics: [DashboardSection] = [.cpu, .gpu, .memory, .disk, .network, .sensors, .fans]
    var id: Self { self }
    var isMetric: Bool { Self.metrics.contains(self) }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .network: "Network"
        case .sensors: "Sensors"
        case .fans: "Fans"
        case .apps: "Processes"
        case .cleanUp: "Clean Up"
        case .system: "This Mac"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.xyaxis.line"
        case .cpu: "cpu"
        case .gpu: "square.stack.3d.up"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "network"
        case .sensors: "thermometer.medium"
        case .fans: "fan"
        case .apps: "list.bullet.rectangle"
        case .cleanUp: "sparkles"
        case .system: "laptopcomputer"
        }
    }

    var tint: Color {
        switch self {
        case .overview, .apps, .cleanUp, .system: .signal
        case .cpu: .blue
        case .gpu: .pink
        case .memory: .purple
        case .disk: .orange
        case .network: .green
        case .sensors: .red
        case .fans: .teal
        }
    }
}

/// Which section the dashboard shows; the panel's cards set it before opening the window.
@MainActor @Observable final class DashboardNavigation {
    static let shared = DashboardNavigation()
    var section: DashboardSection? = .overview {
        didSet { if let section { UserDefaults.standard.set(section.rawValue, forKey: Prefs.dashboardLastSection) } }
    }
    var query = ""
}

/// Created on demand and torn down on close. A SwiftUI `Window` scene stays alive offscreen
/// and kept redrawing its charts while hidden.
@MainActor enum DashboardWindow {
    static var monitor: Monitor?
    private static var window: NSWindow?

    static func show(_ section: DashboardSection?, activate: Bool = true) {
        guard let monitor else { return }
        let nav = DashboardNavigation.shared
        if let section {
            nav.section = section
        } else if window == nil {
            let openTo = Prefs.string(Prefs.dashboardOpenTo, default: "last")
            let key = openTo == "last" ? Prefs.string(Prefs.dashboardLastSection, default: "overview") : openTo
            nav.section = DashboardSection(rawValue: key) ?? .overview
        }
        if window == nil {
            if activate, Prefs.bool(Prefs.showInDock, default: true) { NSApp.setActivationPolicy(.regular) }
            let host = NSHostingController(rootView: DashboardView(monitor: monitor))
            host.sceneBridgingOptions = .all  // lets SwiftUI install the toolbar, title and search field
            let w = NSWindow(contentViewController: host)
            w.title = "Sonar"
            w.styleMask.insert(.fullSizeContentView)
            w.toolbarStyle = .unified
            w.setContentSize(NSSize(width: 1080, height: 740))
            w.minSize = NSSize(width: 760, height: 520)
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("SonarDashboard")
            if !w.setFrameUsingName("SonarDashboard") { w.center() }
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { note in
                MainActor.assumeIsolated {
                    // AppKit can keep a closed window around; detach the SwiftUI tree so it stops updating.
                    (note.object as? NSWindow)?.contentViewController = nil
                    window = nil
                    DashboardNavigation.shared.query = ""
                    Cleaner.shared.reset()
                    NSApp.setActivationPolicy(.accessory)
                    resignActiveIfNoWindows(closing: note.object as? NSWindow)
                }
            }
            window = w
        }
        guard activate else {
            window?.orderBack(nil)  // screenshots: on screen but behind everything, without taking focus
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static var windowNumber: Int? { window?.windowNumber }
}

struct DashboardView: View {
    let monitor: Monitor
    @Bindable private var nav = DashboardNavigation.shared
    @State private var metricsExpanded = true
    @AppStorage(Prefs.dashboardRange) private var range = TimeRange.fifteenMinutes.rawValue
    // Read so every page redraws when units change.
    @AppStorage(TemperatureUnit.storageKey) private var unit = TemperatureUnit.system.rawValue
    @AppStorage(Prefs.storageBinary) private var binary = false
    @AppStorage(Prefs.networkBits) private var bits = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 214, max: 280)
        } detail: {
            detail
                .navigationTitle(nav.query.isEmpty || nav.section == .apps ? (nav.section ?? .overview).title : "Search")
                .navigationSubtitle(subtitle)
                .toolbar {
                    if showsRange {
                        ToolbarItem(placement: .primaryAction) {
                            Picker("Time range", selection: $range) {
                                ForEach(TimeRange.allCases) { Text($0.short).tag($0.rawValue).help($0.long) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            SettingsWindow.open()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .help("Settings (⌘,)")
                    }
                }
                .searchable(text: $nav.query, placement: .toolbar, prompt: "Search apps, sensors, sections")
        }
        .onChange(of: nav.section) { _, new in
            if new?.isMetric == true { metricsExpanded = true }  // reveal the selected sub-item
        }
        .onAppear(perform: monitor.viewAppeared)
        .onDisappear(perform: monitor.viewDisappeared)
    }

    private var showsRange: Bool {
        guard nav.query.isEmpty, let s = nav.section else { return false }
        return s != .apps && s != .cleanUp && s != .system && s != .sensors
    }

    private var subtitle: String {
        guard nav.query.isEmpty || nav.section == .apps else { return "" }
        switch nav.section ?? .overview {
        case .system: return "About this Mac"
        case .cleanUp: return "Moves files to the Trash"
        case .apps: return monitor.processes.isEmpty ? "Running now" : "\(monitor.processes.count) running"
        case .sensors: return "\(monitor.sensors.count) sensors"
        default: return (TimeRange(rawValue: range) ?? .fifteenMinutes).long
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $nav.section) {
            Section {
                DisclosureGroup(isExpanded: $metricsExpanded) {
                    ForEach(DashboardSection.metrics) { row($0).tag($0) }
                } label: {
                    row(.overview).padding(.leading, 4).tag(DashboardSection.overview)  // breathing room after the chevron
                }
            } header: {
                BrandLockup().padding(.top, 6).padding(.bottom, 26)
            }
            Section("Manage") {
                row(.apps).tag(DashboardSection.apps)
                row(.cleanUp).tag(DashboardSection.cleanUp)
            }
            Section("Mac") { row(.system).tag(DashboardSection.system) }
        }
        .listStyle(.sidebar)
        .environment(\.sidebarRowSize, .small)
    }

    /// A standard sidebar row: icon tinted by the system accent, live value as a sidebar badge.
    private func row(_ s: DashboardSection) -> some View {
        Label(s.title, systemImage: s.symbol)
            .badge(sidebarValue(s).map { Text($0).monospacedDigit() })
    }

    private func sidebarValue(_ s: DashboardSection) -> String? {
        switch s {
        case .cpu: Fmt.percent(monitor.cpu)
        case .gpu: Fmt.percent(monitor.gpu)
        case .memory: Fmt.percent(monitor.memoryPercent)
        case .disk: Fmt.storage(monitor.diskFree)
        case .network: Fmt.rate(monitor.down)
        case .sensors: monitor.cpuTemp.map { "\(Int(TemperatureUnit.convert($0).rounded()))°" }
        case .fans: monitor.fanRPMs.max().map { $0 < 1 ? "Off" : "\(Int($0))" }
        case .apps: "\(monitor.apps.count)"
        default: nil
        }
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if !nav.query.isEmpty && nav.section != .apps {
            SearchResults(monitor: monitor, query: nav.query) { section, keepQuery in
                if !keepQuery { nav.query = "" }
                nav.section = section
            }
        } else {
            switch nav.section ?? .overview {
            case .overview: OverviewPage(monitor: monitor)
            case .cpu: CPUPage(monitor: monitor)
            case .gpu: GPUPage(monitor: monitor)
            case .memory: MemoryPage(monitor: monitor)
            case .disk: DiskPage(monitor: monitor)
            case .network: NetworkPage(monitor: monitor)
            case .sensors: SensorsPage(sensors: monitor.sensors)
            case .fans: FansPage(monitor: monitor)
            case .apps: ProcessesPage(monitor: monitor, query: nav.query)
            case .cleanUp: ScrollView { CleanUpCard().padding(20) }
            case .system: ThisMacPage(monitor: monitor)
            }
        }
    }
}

/// ⌘F results across sections, apps and sensors. Clicking one opens its page.
private struct SearchResults: View {
    let monitor: Monitor
    let query: String
    let open: (_ section: DashboardSection, _ keepQuery: Bool) -> Void

    var body: some View {
        let q = query.lowercased()
        let sections = DashboardSection.allCases.filter { $0.title.lowercased().contains(q) }
        let apps = monitor.apps.filter { $0.name.lowercased().contains(q) }
        let sensors = monitor.sensors.filter { "\($0.group) \($0.id)".lowercased().contains(q) }
        List {
            if !sections.isEmpty {
                Section("Sections") {
                    ForEach(sections) { s in
                        result {
                            open(s, false)
                        } label: {
                            Label(s.title, systemImage: s.symbol)
                        }
                    }
                }
            }
            if !apps.isEmpty {
                Section("Apps") {
                    ForEach(apps) { app in
                        result {
                            open(.apps, true)
                        } label: {
                            HStack {
                                if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                                Text(app.name)
                                Spacer()
                                Text("\(Fmt.memory(app.memory)) · \(Fmt.percent(app.cpu, decimals: 1))").foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            if !sensors.isEmpty {
                Section("Sensors") {
                    ForEach(sensors.prefix(20)) { s in
                        result {
                            open(.sensors, false)
                        } label: {
                            HStack {
                                Text(s.group)
                                Text(s.id).font(.caption.monospaced()).foregroundStyle(.tertiary)
                                Spacer()
                                Text(TemperatureUnit.format(s.value, decimals: 1)).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty && apps.isEmpty && sensors.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func result(_ action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) { label().contentShape(Rectangle()) }.buttonStyle(.plain)
    }
}
