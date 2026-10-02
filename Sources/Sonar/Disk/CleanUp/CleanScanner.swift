import SwiftUI

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
