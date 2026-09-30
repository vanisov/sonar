import AppKit
import SwiftUI

/// One row in the Processes table: an app (with its helpers folded in) or a single background process.
struct ProcessRow: Identifiable {
    enum Lock {
        case otherUser  // owned by root or another user: can't be read or ended without admin rights
        case protected  // yours, but ending it would log you out or break the session
    }

    let id: pid_t
    let name: String
    let user: String
    var cpu: Double?
    var memory: UInt64?
    var threads: Int?
    var locked: Lock?
    var app: NSRunningApplication?
    var processCount = 1  // for apps: the app plus its helpers

    var isApp: Bool { app != nil }

    /// Ending these logs you out or takes the session down, even though they run as you.
    static let protectedNames: Set<String> = ["loginwindow", "launchd", "WindowServer", "kernel_task"]

    @MainActor private static var iconCache: [pid_t: NSImage] = [:]

    @MainActor static func clearIconCache() { iconCache = [:] }

    /// App icons come from disk, so cache them for the life of the process.
    @MainActor var icon: NSImage? {
        guard let app else { return nil }
        if let cached = Self.iconCache[id] { return cached }
        let icon = app.icon
        Self.iconCache[id] = icon
        return icon
    }

    var executableURL: URL? {
        if let url = app?.bundleURL { return url }
        var path = [CChar](repeating: 0, count: 4096)
        return proc_pidpath(id, &path, UInt32(path.count)) > 0 ? URL(fileURLWithPath: String(cString: path)) : nil
    }
}

@MainActor enum ProcessActions {
    /// Quit asks nicely (apps can still ask to save); force ends immediately. Returns a status line to show.
    static func end(_ row: ProcessRow, force: Bool) -> String {
        if let app = row.app {
            let sent = force ? app.forceTerminate() : app.terminate()
            return sent ? (force ? "Force quit \(row.name)" : "Asked \(row.name) to quit") : "\(row.name) didn't respond. Try Force Quit."
        }
        if kill(row.id, force ? SIGKILL : SIGTERM) == 0 {
            return force ? "Ended \(row.name)" : "Asked \(row.name) to end"
        }
        return errno == EPERM ? "Sonar isn't allowed to end \(row.name)." : "\(row.name) has already ended."
    }
}

struct ProcessesPage: View {
    let monitor: Monitor
    let query: String

    enum Tab: String, CaseIterable {
        case all = "All", apps = "Applications", background = "Background"
    }

    enum SortKey { case name, cpu, memory, threads, pid, user }

    @State private var tab = Tab.all
    @State private var sortKey = SortKey.memory
    @State private var descending = true
    @State private var selection = Set<pid_t>()
    @State private var showInfo = false
    @State private var pendingForce: [ProcessRow] = []
    @State private var status: String?
    @AppStorage(Prefs.confirmForce) private var confirmForce = true
    @AppStorage(Prefs.showSystemProcesses) private var showSystem = true

    var body: some View {
        let rows = filtered
        let apps = sorted(rows.filter(\.isApp))
        let background = sorted(rows.filter { !$0.isApp })
        VStack(spacing: 0) {
            HStack {
                Picker("Show", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if let status { Text(status).font(.callout).foregroundStyle(.secondary) }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 10)
            controlBar
                .padding(.horizontal, 20).padding(.vertical, 10)
            header
            processList(apps: apps, background: background)
        }
        .onAppear(perform: monitor.processesAppeared)
        .onDisappear(perform: monitor.processesDisappeared)
        .overlay {
            if monitor.processes.isEmpty {
                ProgressView()
            } else if apps.isEmpty && background.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .confirmationDialog(
            forceTitle(pendingForce),
            isPresented: Binding(get: { !pendingForce.isEmpty }, set: { if !$0 { pendingForce = [] } })
        ) {
            Button(verb(pendingForce, force: true), role: .destructive) { perform(pendingForce, force: true) }
        } message: {
            Text(pendingForce.contains(where: \.isApp) ? "Unsaved changes will be lost." : "The processes stop immediately.")
        }
    }

    private func processList(apps: [ProcessRow], background: [ProcessRow]) -> some View {
        List(selection: $selection) {
            if tab != .background && !apps.isEmpty {
                Section("Applications · \(apps.count)") {
                    ForEach(apps, id: \.id) { (r: ProcessRow) in row(r).tag(r.id) }
                }
            }
            if tab != .apps && !background.isEmpty {
                Section("Background processes · \(background.count)") {
                    ForEach(background, id: \.id) { (r: ProcessRow) in row(r).tag(r.id) }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, 24)
        .contextMenu(forSelectionType: pid_t.self) { (ids: Set<pid_t>) in
            menu(for: rows(ids))
        } primaryAction: { (ids: Set<pid_t>) in
            selection = ids
            showInfo = true  // double-click shows details
        }
    }

    // MARK: Selection and actions

    private func rows(_ ids: Set<pid_t>) -> [ProcessRow] { monitor.processes.filter { ids.contains($0.id) } }

    /// Selected rows that Sonar is allowed to end.
    private var actionable: [ProcessRow] { rows(selection).filter { $0.locked == nil } }

    /// "Quit" for apps, "End" for background processes.
    private func verb(_ rows: [ProcessRow], force: Bool) -> String {
        let apps = rows.allSatisfy(\.isApp)
        return force ? (apps ? "Force Quit" : "Force End") : (apps ? "Quit" : "End")
    }

    private func forceTitle(_ rows: [ProcessRow]) -> String {
        guard let first = rows.first else { return "" }
        let what = rows.count == 1 ? first.name : "\(rows.count) processes"
        return rows.allSatisfy(\.isApp) ? "Force quit \(what)?" : "Force end \(what)?"
    }

    /// What's selected on the left, labeled actions on the right. Always visible, so it's obvious what you can do.
    private var controlBar: some View {
        let selected = rows(selection)
        let targets = actionable
        return HStack(spacing: 10) {
            selectionSummary(selected)
            Spacer(minLength: 12)
            Button {
                request(targets, force: false)
            } label: {
                Label(verb(targets, force: false), systemImage: "xmark.circle")
            }
            .help("\(verb(targets, force: false)) the selection (⌘⌫). Apps can still ask to save.")
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(targets.isEmpty)

            Button {
                request(targets, force: true)
            } label: {
                Label(verb(targets, force: true), systemImage: "exclamationmark.octagon")
            }
            .tint(.red)
            .help("\(verb(targets, force: true)) the selection immediately (⌥⌘⌫)")
            .keyboardShortcut(.delete, modifiers: [.command, .option])
            .disabled(targets.isEmpty)

            Button {
                reveal(selected)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            .disabled(selected.allSatisfy { $0.executableURL == nil })

            Button {
                showInfo.toggle()
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            .help("Details (⌘I or double-click a process)")
            .keyboardShortcut("i", modifiers: .command)
            .disabled(selected.isEmpty)
            .popover(isPresented: $showInfo, arrowEdge: .bottom) {
                ProcessInfoView(rows: rows(selection))
            }
        }
        .buttonStyle(.bordered)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.07)))
    }

    @ViewBuilder private func selectionSummary(_ selected: [ProcessRow]) -> some View {
        if selected.count == 1, let row = selected.first {
            HStack(spacing: 8) {
                Group {
                    if let icon = row.icon {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "gearshape").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(summaryLine(row)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } else if selected.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(selected.count) processes selected").font(.callout.weight(.semibold))
                Text(
                    "\(Fmt.memory(selected.compactMap(\.memory).reduce(0, +))) · \(Fmt.percent(selected.compactMap(\.cpu).reduce(0, +), decimals: 1)) CPU"
                        + (selected.contains { $0.locked != nil } ? " · locked ones are skipped" : "")
                )
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } else {
            Label("Select a process to quit it or see details. ⌘-click selects several.", systemImage: "cursorarrow.click")
                .font(.callout).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func summaryLine(_ row: ProcessRow) -> String {
        if row.locked == .otherUser { return "Owned by \(row.user) · can't be ended" }
        if row.locked == .protected { return "Part of your login session · can't be ended" }
        let memory = row.memory.map { Fmt.memory($0) } ?? "—"
        let cpu = row.cpu.map { Fmt.percent($0, decimals: 1) } ?? "—"
        return row.isApp ? "\(memory) · \(cpu) CPU · \(row.processCount) processes" : "\(memory) · \(cpu) CPU · PID \(row.id)"
    }

    @ViewBuilder private func menu(for rows: [ProcessRow]) -> some View {
        let targets = rows.filter { $0.locked == nil }
        if !targets.isEmpty {
            Button(verb(targets, force: false)) { request(targets, force: false) }
            Button(verb(targets, force: true) + "…") { request(targets, force: true) }
            Divider()
        }
        Button("Show in Finder") { reveal(rows) }
        Button("Get Info") {
            selection = Set(rows.map(\.id))
            showInfo = true
        }
        Button(rows.count == 1 ? "Copy PID" : "Copy PIDs") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(rows.map { String($0.id) }.joined(separator: " "), forType: .string)
        }
    }

    private func reveal(_ rows: [ProcessRow]) {
        let urls = rows.compactMap(\.executableURL)
        if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }

    /// Quit/End right away; forceful actions ask first unless that's turned off in Settings.
    private func request(_ rows: [ProcessRow], force: Bool) {
        guard !rows.isEmpty else { return }
        if force && confirmForce { pendingForce = rows } else { perform(rows, force: force) }
    }

    private func perform(_ rows: [ProcessRow], force: Bool) {
        let messages = rows.map { ProcessActions.end($0, force: force) }
        let message =
            messages.count == 1
            ? messages[0]
            : "\(force ? "Force ended" : "Asked") \(rows.count) processes\(force ? "" : " to \(verb(rows, force: false).lowercased())")"
        status = message
        selection.subtract(rows.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(4))
            if status == message { status = nil }
        }
    }

    // MARK: Filtering and sorting

    private var filtered: [ProcessRow] {
        let q = query.lowercased()
        return monitor.processes.filter { row in
            (showSystem || row.locked != .otherUser) && (q.isEmpty || row.name.lowercased().contains(q) || "\(row.id)" == q)
        }
    }

    private func sorted(_ rows: [ProcessRow]) -> [ProcessRow] {
        func less(_ a: ProcessRow, _ b: ProcessRow) -> Bool {
            switch sortKey {
            case .name: a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .cpu: (a.cpu ?? -1) < (b.cpu ?? -1)
            case .memory: (a.memory ?? 0) < (b.memory ?? 0)
            case .threads: (a.threads ?? -1) < (b.threads ?? -1)
            case .pid: a.id < b.id
            case .user: a.user < b.user
            }
        }
        // Ties (common: many processes at 0.0% CPU) fall back to PID so rows don't swap places between updates.
        return rows.sorted { a, b in
            if less(a, b) == less(b, a) { return a.id < b.id }
            return descending ? less(b, a) : less(a, b)
        }
    }

    // MARK: Columns

    private static let widths: (cpu: CGFloat, memory: CGFloat, threads: CGFloat, pid: CGFloat, user: CGFloat) = (64, 86, 64, 64, 96)

    private var header: some View {
        HStack(spacing: 0) {
            column("Name", .name).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 28)
            column("% CPU", .cpu).frame(width: Self.widths.cpu, alignment: .trailing)
            column("Memory", .memory).frame(width: Self.widths.memory, alignment: .trailing)
            column("Threads", .threads).frame(width: Self.widths.threads, alignment: .trailing)
            column("PID", .pid).frame(width: Self.widths.pid, alignment: .trailing)
            column("User", .user).frame(width: Self.widths.user, alignment: .leading).padding(.leading, 14)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 28).padding(.bottom, 6)
    }

    private func column(_ title: String, _ key: SortKey) -> some View {
        Button {
            if sortKey == key { descending.toggle() } else { (sortKey, descending) = (key, key != .name && key != .user) }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if sortKey == key { Image(systemName: descending ? "chevron.down" : "chevron.up").font(.system(size: 8, weight: .bold)) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ row: ProcessRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Group {
                    if let icon = row.icon {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "gearshape").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 16, height: 16)
                Text(row.name).lineLimit(1).truncationMode(.middle)
                if row.locked != nil {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.tertiary)
                        .help(row.locked == .otherUser ? "Owned by \(row.user)" : "Part of your login session")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.cpu.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—").frame(
                width: Self.widths.cpu, alignment: .trailing)
            Text(row.memory.map { Fmt.memory($0) } ?? "—").frame(width: Self.widths.memory, alignment: .trailing)
            Text(row.threads.map(String.init) ?? "—").frame(width: Self.widths.threads, alignment: .trailing)
            Text(verbatim: String(row.id)).foregroundStyle(.secondary).frame(width: Self.widths.pid, alignment: .trailing)
            Text(row.user).foregroundStyle(.secondary).lineLimit(1).frame(width: Self.widths.user, alignment: .leading).padding(
                .leading, 14)
        }
        .font(.system(size: 12))
        .monospacedDigit()
    }
}

/// Details for the selected processes (the toolbar's Info button, or double-click).
private struct ProcessInfoView: View {
    let rows: [ProcessRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if rows.count == 1, let row = rows.first {
                HStack(spacing: 10) {
                    Group {
                        if let icon = row.icon {
                            Image(nsImage: icon).resizable()
                        } else {
                            Image(systemName: "gearshape.fill").font(.system(size: 20)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).font(.headline).lineLimit(1)
                        Text(
                            verbatim: row.isApp
                                ? "Application · \(row.processCount) processes · PID \(row.id)" : "Background process · PID \(row.id)"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        detail("CPU", row.cpu.map { Fmt.percent($0, decimals: 1) } ?? "—")
                        detail("Memory", row.memory.map { Fmt.memory($0) } ?? "—")
                    }
                    GridRow {
                        detail("Threads", row.threads.map(String.init) ?? "—")
                        detail("User", row.user)
                    }
                }
                if let path = row.executableURL?.path {
                    Text(path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                }
                if let lock = row.locked {
                    Label(
                        lock == .otherUser
                            ? "Owned by \(row.user). Sonar doesn't end other users' or system processes."
                            : "Part of your login session. Ending it would log you out, so Sonar won't.",
                        systemImage: "lock.fill"
                    )
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("\(rows.count) processes").font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        detail("CPU", Fmt.percent(rows.compactMap(\.cpu).reduce(0, +), decimals: 1))
                        detail("Memory", Fmt.memory(rows.compactMap(\.memory).reduce(0, +)))
                    }
                }
                Text(rows.prefix(8).map(\.name).joined(separator: ", ") + (rows.count > 8 ? "…" : ""))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 290)
    }

    private func detail(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text(value).monospacedDigit().lineLimit(1)
        }
    }
}
