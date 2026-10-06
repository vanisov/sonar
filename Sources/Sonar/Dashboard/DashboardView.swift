import SwiftUI

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
        return s != .apps && s != .system && s != .sensors
    }

    private var subtitle: String {
        guard nav.query.isEmpty || nav.section == .apps else { return "" }
        switch nav.section ?? .overview {
        case .system: return "About this Mac"
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
            Section("Manage") { row(.apps).tag(DashboardSection.apps) }
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
            case .system: ThisMacPage(monitor: monitor)
            }
        }
    }
}
