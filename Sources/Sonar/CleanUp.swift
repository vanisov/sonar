import AppKit
import SwiftUI

/// A file or folder Clean Up can move to the Trash.
struct CleanItem: Identifiable {
    let url: URL
    var name: String
    let size: Int64
    var id: URL { url }
}

struct CleanCategory: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    var items: [CleanItem] = []
    var size: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// Finds space that's safe to reclaim, only when asked, and moves what you pick to the Trash. Nothing is deleted,
/// nothing outside your home folder is touched, and no admin rights are needed.
@MainActor @Observable final class Cleaner {
    /// Kept while the dashboard is open so switching sections doesn't throw away a scan; cleared when it closes.
    static let shared = Cleaner()

    enum Phase: Equatable {
        case idle
        case scanning(String)
        case ready
        case cleaning
        case done(moved: Int64, failed: Int)
    }

    var phase = Phase.idle
    var categories: [CleanCategory] = []
    var selection: Set<URL> = []

    var selectedSize: Int64 {
        categories.flatMap(\.items).filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func scan() {
        phase = .scanning("")
        categories = []
        selection = []
        let running = NSWorkspace.shared.runningApplications.map { (id: $0.bundleIdentifier, name: $0.localizedName) }
        Task.detached(priority: .utility) {
            for (title, find) in CleanScanner.categories(running: running) {
                // Stop if the dashboard closed (reset) mid-scan.
                guard await MainActor.run(body: { self.isScanning }) else { return }
                await MainActor.run { self.phase = .scanning(title) }
                let category = find()
                await MainActor.run { if self.isScanning { self.add(category) } }
            }
            await MainActor.run { if self.isScanning { self.phase = .ready } }
        }
    }

    private var isScanning: Bool {
        if case .scanning = phase { true } else { false }
    }

    private func add(_ category: CleanCategory) {
        guard !category.items.isEmpty else { return }
        categories.append(category)
        selection.formUnion(category.items.map(\.url))
    }

    func reset() {
        guard phase != .cleaning else { return }
        phase = .idle
        categories = []
        selection = []
    }

    func clean() {
        let picked = categories.flatMap(\.items).filter { selection.contains($0.url) }
        phase = .cleaning
        Task.detached(priority: .userInitiated) {
            var moved: Int64 = 0
            var trashed: Set<URL> = []
            for item in picked {
                do {
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    moved += item.size
                    trashed.insert(item.url)
                } catch {}
            }
            let (movedTotal, trashedURLs) = (moved, trashed)
            await MainActor.run {
                for i in self.categories.indices { self.categories[i].items.removeAll { trashedURLs.contains($0.url) } }
                self.categories.removeAll { $0.items.isEmpty }
                self.selection.subtract(trashedURLs)
                self.phase = .done(moved: movedTotal, failed: picked.count - trashedURLs.count)
            }
        }
    }

    func isSelected(_ c: CleanCategory) -> Binding<Bool> {
        Binding(
            get: { c.items.allSatisfy { self.selection.contains($0.url) } },
            set: { on in
                let urls = c.items.map(\.url)
                if on { self.selection.formUnion(urls) } else { self.selection.subtract(urls) }
            })
    }

    func isSelected(_ item: CleanItem) -> Binding<Bool> {
        Binding(
            get: { self.selection.contains(item.url) },
            set: { on in
                if on { self.selection.insert(item.url) } else { self.selection.remove(item.url) }
            })
    }
}

/// The categories and where they live. Runs off the main thread.
enum CleanScanner {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let caches = home.appending(path: "Library/Caches")
    private static let xcode = home.appending(path: "Library/Developer/Xcode")

    /// Package manager caches: (name, path relative to home). Those inside ~/Library/Caches are left out of App caches.
    private static let packageCaches = [
        ("Homebrew", "Library/Caches/Homebrew"), ("npm", ".npm/_cacache"), ("Yarn", "Library/Caches/Yarn"),
        ("pip", "Library/Caches/pip"), ("CocoaPods", "Library/Caches/CocoaPods"), ("Go build", "Library/Caches/go-build"),
        ("Bun", ".bun/install/cache"), ("pnpm", "Library/Caches/pnpm"),
    ]

    /// Not caches despite living in Caches: nothing downloads these again by itself.
    private static let keep = ["ms-playwright"]

    static func categories(running: [(id: String?, name: String?)]) -> [(String, () -> CleanCategory)] {
        let packageNames = Set(packageCaches.map { ($0.1 as NSString).lastPathComponent })
        return [
            (
                "App caches",
                {
                    // Apple's own caches are skipped, and so are those of apps that are running right now. Folders are
                    // named by bundle ID ("com.spotify.client") or vendor ("Google" for Chrome, "BraveSoftware").
                    // ponytail: name matching, misses vendors unlike their app's name; check open files if that bites.
                    let runningNames = running.flatMap { app in
                        [app.id?.lowercased(), app.name?.split(separator: " ").first.map { $0.lowercased() }].compactMap { $0 }
                    }
                    .filter { $0.count >= 4 }
                    let items = children(of: caches).filter { url in
                        let name = url.lastPathComponent
                        let lower = name.lowercased()
                        return !name.hasPrefix("com.apple.") && !packageNames.contains(name) && !keep.contains { name.hasPrefix($0) }
                            && !runningNames.contains { lower.hasPrefix($0) }
                    }
                    return CleanCategory(
                        id: "caches", title: "App caches", detail: "Apps rebuild these when needed. Running apps are skipped.",
                        symbol: "archivebox", items: sized(items))
                }
            ),
            (
                "Logs",
                {
                    CleanCategory(
                        id: "logs", title: "Logs and crash reports", detail: "Old diagnostics apps don't need.",
                        symbol: "doc.text", items: sized(children(of: home.appending(path: "Library/Logs"))))
                }
            ),
            (
                "Package caches",
                {
                    let items = packageCaches.map { home.appending(path: $0.1) }
                        .filter { FileManager.default.fileExists(atPath: $0.path) }
                    var sizedItems = sized(items)
                    for i in sizedItems.indices {
                        sizedItems[i].name =
                            packageCaches.first { home.appending(path: $0.1) == sizedItems[i].url }?.0 ?? sizedItems[i].name
                    }
                    return CleanCategory(
                        id: "packages", title: "Package manager caches", detail: "Downloaded again when a package is needed.",
                        symbol: "shippingbox", items: sizedItems)
                }
            ),
            (
                "Xcode",
                {
                    CleanCategory(
                        id: "derivedData", title: "Xcode build data", detail: "DerivedData. Xcode rebuilds it on the next build.",
                        symbol: "hammer", items: sized(children(of: xcode.appending(path: "DerivedData"))))
                }
            ),
            (
                "Xcode",
                {
                    let platforms = ["iOS", "watchOS", "tvOS", "visionOS"]
                    let items = platforms.flatMap { children(of: xcode.appending(path: "\($0) DeviceSupport")) }
                    var sizedItems = sized(items)
                    for i in sizedItems.indices {
                        sizedItems[i].name = sizedItems[i].url.deletingLastPathComponent().lastPathComponent + " · " + sizedItems[i].name
                    }
                    return CleanCategory(
                        id: "deviceSupport", title: "Device support files",
                        detail: "Xcode downloads them again when you connect a device.", symbol: "iphone", items: sizedItems)
                }
            ),
        ]
    }

    private static func children(of dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
    }

    /// Items with their size on disk, largest first. Empty ones are dropped, and so is anything written to in the last
    /// hour: something (an app, a command-line tool, a system service) is using it right now.
    private static func sized(_ urls: [URL]) -> [CleanItem] {
        let inUse = Date.now.addingTimeInterval(-3600)
        return urls.compactMap { url in
            let (size, lastWrite) = scan(url)
            return size > 0 && lastWrite < inUse ? CleanItem(url: url, name: url.lastPathComponent, size: size) : nil
        }
        .sorted { $0.size > $1.size }
    }

    /// Size on disk and the newest modification date of a file or everything inside a folder.
    static func scan(_ url: URL) -> (size: Int64, lastWrite: Date) {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey]
        guard let v = try? url.resourceValues(forKeys: keys) else { return (0, .distantPast) }
        var size = Int64(v.totalFileAllocatedSize ?? 0)
        var lastWrite = v.contentModificationDate ?? .distantPast
        guard v.isDirectory == true else { return (size, lastWrite) }
        let files = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true })
        while let file = files?.nextObject() as? URL {
            guard let f = try? file.resourceValues(forKeys: keys) else { continue }
            size += Int64(f.totalFileAllocatedSize ?? 0)
            if let date = f.contentModificationDate, date > lastWrite { lastWrite = date }
        }
        return (size, lastWrite)
    }
}

/// The Clean Up page.
struct CleanUpCard: View {
    private var cleaner = Cleaner.shared
    @State private var expanded: Set<String> = []

    var body: some View {
        DashCard(title: "Safe to remove", symbol: "sparkles", tint: .signal) {
            switch cleaner.phase {
            case .idle:
                HStack {
                    Text("Find caches, logs and build leftovers that are safe to remove. Nothing is deleted until you empty the Trash.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                    Button("Scan") { cleaner.scan() }.buttonStyle(.borderedProminent).tint(.signal)
                }
            default:
                if case .done(let moved, let failed) = cleaner.phase { doneBanner(moved: moved, failed: failed) }
                list
                footer
            }
        }
        #if DEBUG
            .onAppear { if CommandLine.arguments.contains("--scan") { cleaner.scan() } }  // README screenshots
        #endif
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(cleaner.categories) { c in
                if c.id != cleaner.categories.first?.id { Divider() }
                categoryRow(c)
                if expanded.contains(c.id) {
                    ForEach(c.items.prefix(100)) { item in itemRow(item) }
                    if c.items.count > 100 {
                        Text("and \(c.items.count - 100) more").font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 56).padding(.vertical, 4)
                    }
                }
            }
            if case .scanning(let what) = cleaner.phase {
                if !cleaner.categories.isEmpty { Divider() }
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(what.isEmpty ? "Scanning…" : "Scanning \(what)…").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if cleaner.categories.isEmpty {
                Text("Nothing to clean up.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(
                    .vertical, 6)
            }
        }
    }

    private func categoryRow(_ c: CleanCategory) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: cleaner.isSelected(c)).toggleStyle(.checkbox).labelsHidden()
            Image(systemName: c.symbol).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.title)
                Text(c.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(Fmt.storage(c.size)).monospacedDigit()
            Button {
                if expanded.contains(c.id) { expanded.remove(c.id) } else { expanded.insert(c.id) }
            } label: {
                Image(systemName: "chevron.right").rotationEffect(.degrees(expanded.contains(c.id) ? 90 : 0))
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help(expanded.contains(c.id) ? "Hide items" : "Show \(c.items.count) items")
        }
        .padding(.vertical, 7)
    }

    private func itemRow(_ item: CleanItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: cleaner.isSelected(item)).toggleStyle(.checkbox).labelsHidden().controlSize(.small)
            Text(item.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 12)
            Text(Fmt.storage(item.size)).font(.callout).foregroundStyle(.secondary).monospacedDigit()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).help("Show in Finder")
            .frame(width: 20)
        }
        .padding(.leading, 28).padding(.vertical, 3)
    }

    private var footer: some View {
        HStack {
            Button("Scan Again") { cleaner.scan() }.disabled(isBusy)
            Spacer()
            Button(cleaner.selection.isEmpty ? "Move to Trash" : "Move \(Fmt.storage(cleaner.selectedSize)) to Trash") { cleaner.clean() }
                .buttonStyle(.borderedProminent).tint(.signal)
                .disabled(cleaner.selection.isEmpty || isBusy)
        }
        .padding(.top, 4)
    }

    private var isBusy: Bool {
        switch cleaner.phase {
        case .scanning, .cleaning: true
        default: false
        }
    }

    private func doneBanner(moved: Int64, failed: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text("Moved \(Fmt.storage(moved)) to the Trash.")
                Text(
                    failed > 0
                        ? "\(failed) item\(failed == 1 ? "" : "s") couldn't be moved. Empty the Trash to free the space."
                        : "Empty the Trash to free the space. Until then, you can put anything back."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Trash") {
                if let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first { NSWorkspace.shared.open(trash) }
            }
        }
        .padding(10)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
