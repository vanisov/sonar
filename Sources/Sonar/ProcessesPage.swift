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
    @State private var selected: pid_t?
    @State private var pendingForce: ProcessRow?
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
                Text("Click a process to see details and end it").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            header
            List {
                if tab != .background && !apps.isEmpty {
                    Section("Applications · \(apps.count)") { ForEach(apps) { row($0) } }
                }
                if tab != .apps && !background.isEmpty {
                    Section("Background processes · \(background.count)") { ForEach(background) { row($0) } }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .environment(\.defaultMinListRowHeight, 24)
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
            pendingForce.map { $0.isApp ? "Force quit \($0.name)?" : "Force end \($0.name)?" } ?? "",
            isPresented: Binding(get: { pendingForce != nil }, set: { if !$0 { pendingForce = nil } }),
            presenting: pendingForce
        ) { row in
            Button(row.isApp ? "Force Quit" : "Force End", role: .destructive) { perform(row, force: true) }
        } message: { row in
            Text(row.isApp ? "Unsaved changes in \(row.name) will be lost." : "The process stops immediately.")
        }
    }

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
            // Anchored to the name, opening below it, so the details appear right where you clicked.
            .popover(
                isPresented: Binding(get: { selected == row.id }, set: { if !$0 { selected = nil } }), arrowEdge: .bottom
            ) {
                ProcessPopover(row: row) { force in
                    selected = nil
                    request(row, force: force)
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
        .contentShape(Rectangle())
        .onTapGesture { selected = row.id }
        .contextMenu {
            if row.locked == nil {
                Button(row.isApp ? "Quit" : "End Process") { request(row, force: false) }
                Button(row.isApp ? "Force Quit…" : "Force End…") { request(row, force: true) }
                Divider()
            }
            if let url = row.executableURL {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Button("Copy PID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(String(row.id), forType: .string)
            }
        }
    }

    /// Quit/End right away; forceful actions ask first unless that's turned off in Settings.
    private func request(_ row: ProcessRow, force: Bool) {
        if force && confirmForce { pendingForce = row } else { perform(row, force: force) }
    }

    private func perform(_ row: ProcessRow, force: Bool) {
        let message = ProcessActions.end(row, force: force)
        status = message
        Task {
            try? await Task.sleep(for: .seconds(4))
            if status == message { status = nil }
        }
    }
}

private struct ProcessPopover: View {
    let row: ProcessRow
    let end: (_ force: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    Text(verbatim: row.isApp ? "Application · \(row.processCount) processes" : "Background process · PID \(row.id)")
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
            if let lock = row.locked {
                Label(
                    lock == .otherUser
                        ? "Owned by \(row.user). Sonar doesn't end other users' or system processes."
                        : "Part of your login session. Ending it would log you out, so Sonar won't.",
                    systemImage: "lock.fill"
                )
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    Button {
                        end(false)
                    } label: {
                        Text(row.isApp ? "Quit" : "End Process").frame(maxWidth: .infinity)
                    }
                    Button(role: .destructive) {
                        end(true)
                    } label: {
                        Text(row.isApp ? "Force Quit…" : "Force End…").frame(maxWidth: .infinity)
                    }
                    if let url = row.executableURL {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Text("Show in Finder").frame(maxWidth: .infinity)
                        }
                    }
                }
                .controlSize(.large)
            }
        }
        .padding(16)
        .frame(width: 270)
    }

    private func detail(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text(value).monospacedDigit().lineLimit(1)
        }
    }
}
