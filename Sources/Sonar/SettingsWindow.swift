import ServiceManagement
import SwiftUI

/// Sonar's Settings window: native toolbar tabs, created when opened and torn down on close.
/// (SwiftUI's Settings scene keeps its window, and everything in it, alive after closing.)
@MainActor enum SettingsWindow {
    private static var window: NSWindow?

    static func open() {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            func add(_ title: String, _ symbol: String, _ view: some View) {
                let host = NSHostingController(rootView: view.frame(width: 580))
                host.sizingOptions = .preferredContentSize  // the window resizes to each tab
                host.title = title  // becomes the window title while the tab is selected
                let item = NSTabViewItem(viewController: host)
                item.label = title
                item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
                tabs.addTabViewItem(item)
            }
            add("General", "gearshape", GeneralSettings())
            add("Menu Bar", "menubar.rectangle", MenuBarSettings())
            add("Panel", "rectangle.grid.2x2", PanelSettings())
            add("Dashboard", "chart.xyaxis.line", DashboardSettings())
            add("Units", "ruler", UnitsSettings())
            add("About", "info.circle", AboutSettings())
            let w = NSWindow(contentViewController: tabs)
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { note in
                MainActor.assumeIsolated {
                    (note.object as? NSWindow)?.contentViewController = nil
                    window = nil
                    resignActiveIfNoWindows(closing: note.object as? NSWindow)
                }
            }
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: General

private struct GeneralSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @AppStorage(Prefs.showInDock) private var showInDock = true
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system.rawValue
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch Sonar at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).foregroundStyle(.red).font(.callout) }
                Toggle("Show Sonar in the Dock while the dashboard is open", isOn: $showInDock)
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, v in Appearance(rawValue: v)?.apply() }
            }
            Section {
                LabeledContent("Open the dashboard") { ShortcutRecorder(key: Prefs.dashboardShortcut) }
            } header: {
                Text("Keyboard shortcut")
            } footer: {
                Text("Works from any app. Click it, then press the keys. Esc cancels, Delete removes it.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Restore Default Settings…") { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .frame(height: 400)
        .confirmationDialog("Restore all settings to their defaults?", isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive) {
                Prefs.reset()
                Appearance.system.apply()
                Hotkeys.reload()
            }
        } message: {
            Text("Your menu bar, panel, dashboard, unit and update choices go back to how Sonar ships.")
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update the login item. Launch at login works when Sonar runs from Sonar.app."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: Menu bar

private struct MenuBarSettings: View {
    @AppStorage(Prefs.menuBarItems) private var enabledRaw = MenuBarItem.defaults
    @AppStorage(Prefs.menuBarOrder) private var orderRaw = ""
    @AppStorage(Prefs.menuBarStyles) private var stylesRaw = ""
    @AppStorage(Prefs.menuBarDecimals) private var decimals = 0
    @AppStorage(Prefs.menuBarHighlight) private var highlight = true

    var body: some View {
        let order = MenuBarConfig.order
        Form {
            Section {
                HStack {
                    Spacer()
                    Image(nsImage: MenuBarConfig.previewImage())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .accessibilityLabel("Menu bar preview")
            } header: {
                Text("Preview")
            } footer: {
                Text("With nothing turned on, the menu bar shows the Sonar logo.").foregroundStyle(.secondary)
            }
            Section("Stats · drag to reorder") {
                List {
                    ForEach(order) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).frame(width: 18).foregroundStyle(.secondary)
                            Text(item.title)
                            Spacer()
                            Picker("Style", selection: styleBinding(item)) {
                                ForEach(MenuBarItem.Style.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                            Toggle("Show", isOn: enabledBinding(item)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                    .onMove { from, to in
                        var items = order
                        items.move(fromOffsets: from, toOffset: to)
                        orderRaw = items.map(\.rawValue).joined(separator: ",")
                    }
                }
                .frame(height: CGFloat(order.count) * 34)
            }
            Section {
                Picker("Decimal places", selection: $decimals) {
                    Text("None").tag(0)
                    Text("One").tag(1)
                }
                .pickerStyle(.segmented)
                Toggle("Color values that need attention", isOn: $highlight)
            } footer: {
                Text("Orange above 80% CPU or 194 °F (90 °C); red above 95% or 212 °F (100 °C). Memory follows memory pressure.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 560)
    }

    private func enabledBinding(_ item: MenuBarItem) -> Binding<Bool> {
        Binding {
            MenuBarConfig.enabled.contains(item)
        } set: { on in
            var set = MenuBarConfig.enabled
            if on { set.insert(item) } else { set.remove(item) }
            enabledRaw = set.map(\.rawValue).sorted().joined(separator: ",")
        }
    }

    private func styleBinding(_ item: MenuBarItem) -> Binding<MenuBarItem.Style> {
        Binding {
            MenuBarConfig.style(item)
        } set: { style in
            var styles = MenuBarConfig.styles
            styles[item] = style
            stylesRaw = styles.map { "\($0.key.rawValue)=\($0.value.rawValue)" }.sorted().joined(separator: ",")
        }
    }
}

// MARK: Panel

private struct PanelSettings: View {
    @AppStorage(Prefs.panelCards) private var cardsRaw = PanelCard.defaults
    @AppStorage(Prefs.panelTopApps) private var topApps = 5
    @AppStorage(Prefs.panelSparkline) private var sparkline = 60
    @AppStorage(Prefs.panelCardClick) private var cardOpens = true

    var body: some View {
        let order = PanelCard.order
        Form {
            Section("Cards · drag to reorder") {
                List {
                    ForEach(order) { card in
                        HStack(spacing: 10) {
                            Image(systemName: card.symbol).frame(width: 18).foregroundStyle(card.tint)
                            Text(card.title)
                            Spacer()
                            Toggle("Show", isOn: shownBinding(card)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                    .onMove { from, to in
                        var cards = order
                        cards.move(fromOffsets: from, toOffset: to)
                        let shown = Set(PanelCard.enabled)
                        cardsRaw = PanelCard.encode(order: cards, shown: shown)
                    }
                }
                .frame(height: CGFloat(order.count) * 34)
            }
            Section {
                Picker("Top apps", selection: $topApps) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                    Text("10").tag(10)
                }
                .pickerStyle(.segmented)
                Picker("Sparkline length", selection: $sparkline) {
                    Text("1 min").tag(30)
                    Text("2 min").tag(60)
                    Text("5 min").tag(150)
                }
                .pickerStyle(.segmented)
                Toggle("Clicking a card opens its dashboard page", isOn: $cardOpens)
            }
        }
        .formStyle(.grouped)
        .frame(height: 500)
    }

    private func shownBinding(_ card: PanelCard) -> Binding<Bool> {
        Binding {
            PanelCard.enabled.contains(card)
        } set: { on in
            var shown = Set(PanelCard.enabled)
            if on { shown.insert(card) } else { shown.remove(card) }
            cardsRaw = PanelCard.encode(order: PanelCard.order, shown: shown)
        }
    }
}

// MARK: Dashboard

private struct DashboardSettings: View {
    @AppStorage(Prefs.dashboardOpenTo) private var openTo = "last"
    @AppStorage(Prefs.dashboardRange) private var range = 900
    @AppStorage(Prefs.chartFilled) private var filled = true
    @AppStorage(Prefs.overlayTemperature) private var overlay = true
    @AppStorage(Prefs.cpuTempSource) private var hottest = false

    var body: some View {
        Form {
            Section {
                Picker("Open to", selection: $openTo) {
                    Text("Last section viewed").tag("last")
                    Text("Overview").tag(DashboardSection.overview.rawValue)
                    Text("Apps").tag(DashboardSection.apps.rawValue)
                }
                Picker("Default time range", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.short).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Section("Charts") {
                Picker("Style", selection: $filled) {
                    Text("Filled").tag(true)
                    Text("Line").tag(false)
                }
                .pickerStyle(.segmented)
                Toggle("Overlay temperature on CPU and GPU usage", isOn: $overlay)
            }
            Section {
                Picker("CPU temperature", selection: $hottest) {
                    Text("Average of all CPU sensors").tag(false)
                    Text("Hottest CPU sensor").tag(true)
                }
            } footer: {
                Text("Also used in the panel and the menu bar.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 390)
    }
}

// MARK: Units

private struct UnitsSettings: View {
    @AppStorage(Prefs.temperatureUnit) private var unit = TemperatureUnit.system.rawValue
    @AppStorage(Prefs.storageBinary) private var binary = false
    @AppStorage(Prefs.networkBits) private var bits = false

    var body: some View {
        Form {
            Section {
                Picker("Temperature", selection: $unit) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                .pickerStyle(.segmented)
                Picker("Storage", selection: $binary) {
                    Text("GB, like Finder").tag(false)
                    Text("GiB").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("Network speed", selection: $bits) {
                    Text("Bytes (MB/s)").tag(false)
                    Text("Bits (Mb/s)").tag(true)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("GB counts 1,000 MB. GiB counts 1,024 MiB. Network providers usually quote speeds in bits.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 250)
    }
}

// MARK: About

private struct AboutSettings: View {
    @AppStorage(Prefs.checkForUpdates) private var autoCheck = false
    @AppStorage(Prefs.installUpdates) private var autoInstall = false
    @AppStorage(Prefs.betaUpdates) private var beta = false
    private let updater = Updater.shared
    private let repo = URL(string: "https://github.com/\(Updater.repo)")!

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 22) {
                AppMark(size: 104)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sonar for macOS").font(.title3.bold())
                    Text("Version \(Updater.currentVersion)").foregroundStyle(.secondary).monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Link("Release Notes", destination: repo.appending(path: "blob/main/CHANGELOG.md"))
                        Link("Acknowledgements", destination: repo.appending(path: "blob/main/README.md#thanks"))
                        Link("Privacy", destination: repo.appending(path: "blob/main/README.md#privacy"))
                        Link("MIT License", destination: repo.appending(path: "blob/main/LICENSE"))
                        Link("Source Code", destination: repo)
                    }
                    .padding(.top, 6)
                    Button("Report an Issue…") { NSWorkspace.shared.open(repo.appending(path: "issues/new/choose")) }
                        .padding(.top, 6)
                }
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(
                    "Sonar collects no data and has no analytics. The only network request it makes is the update check below, and only if you turn it on."
                )
                Text("© 2026 Vlad Anisov. Released under the MIT License.")
                Text("Sonar is not affiliated with Apple Inc. Apple, Mac, macOS and Apple silicon are trademarks of Apple Inc.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 460)

            if let notes = ReleaseNotes.current {
                DisclosureGroup("What's new in \(Updater.currentVersion)") {
                    Text(notes).font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }
                .frame(maxWidth: 480)
            }

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Automatically check for updates", isOn: $autoCheck)
                    Toggle("Install updates automatically", isOn: $autoInstall).disabled(!autoCheck)
                    Picker("Update to", selection: $beta) {
                        Text("Stable releases").tag(false)
                        Text("Beta releases").tag(true)
                    }
                    .fixedSize()
                }
                .toggleStyle(.checkbox)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    statusText
                    if case .available = updater.status {
                        Button("Install and Relaunch") { Task { await updater.install() } }
                    } else {
                        Button("Check Now") { Task { await updater.check() } }
                            .disabled(updater.status == .checking || updater.status == .installing)
                    }
                    if let page = updater.latest?.page { Link("Release Notes", destination: page) }
                }
                .font(.callout)
                .multilineTextAlignment(.trailing)
            }
            Text("Checks GitHub releases once a day. Nothing else is sent.").font(.caption).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(width: 580)
    }

    @ViewBuilder private var statusText: some View {
        switch updater.status {
        case .idle:
            Text(updater.lastChecked.map { "Last checked \($0.formatted(.relative(presentation: .named)))" } ?? "Not checked yet")
                .foregroundStyle(.secondary)
        case .checking: Text("Checking…").foregroundStyle(.secondary)
        case .upToDate: Text("Sonar \(Updater.currentVersion) is up to date").foregroundStyle(.secondary)
        case .available(let v): Text("Sonar \(v) is available").bold()
        case .installing: Text("Installing…").foregroundStyle(.secondary)
        case .failed(let message): Text(message).foregroundStyle(.red).frame(maxWidth: 240, alignment: .trailing)
        }
    }
}

/// This version's section of CHANGELOG.md, bundled into Sonar.app by bundle.sh.
enum ReleaseNotes {
    static let current: String? = {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        let version = Updater.currentVersion
        var lines: [String] = []
        var inSection = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## [") {
                if inSection { break }
                inSection = line.hasPrefix("## [\(version)]")
                continue
            }
            guard inSection, !line.hasPrefix("[") else { continue }
            lines.append(
                line.hasPrefix("### ") ? String(line.dropFirst(4)) : line.hasPrefix("- ") ? "• " + line.dropFirst(2) : String(line))
        }
        let notes = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? nil : notes
    }()
}
