import SwiftUI

/// What's using the startup disk, in Apple's categories. macOS computes its own breakdown with a private service, so
/// Sonar measures the same folders itself. The first scan asks for access to Desktop, Documents and Downloads.
enum StorageCategory: String, CaseIterable, Identifiable {
    case applications, documents, photos, music, movies, iCloud, developer, macOS, systemData

    var id: Self { self }

    var title: String {
        switch self {
        case .applications: "Applications"
        case .documents: "Documents"
        case .photos: "Photos"
        case .music: "Music"
        case .movies: "Movies"
        case .iCloud: "iCloud Drive"
        case .developer: "Developer"
        case .macOS: "macOS"
        case .systemData: "System Data"
        }
    }

    var color: Color {
        switch self {
        case .applications: .red
        case .documents: .orange
        case .photos: .yellow
        case .music: .pink
        case .movies: .indigo
        case .iCloud: .cyan
        case .developer: .purple
        case .macOS: Color(white: 0.55)
        case .systemData: Color(white: 0.75)
        }
    }

    /// Folders measured for this category, relative to home unless absolute. macOS is the system volume and System
    /// Data is whatever's left, hidden folders like ~/.npm included, as in System Settings.
    fileprivate var paths: [String] {
        switch self {
        case .applications: ["/Applications", "Applications"]
        case .documents:
            // Like Apple: every visible folder in your home that isn't another category, so ~/Developer counts too.
            ((try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory())) ?? [])
                .filter { !$0.hasPrefix(".") && !["Library", "Pictures", "Music", "Movies", "Applications"].contains($0) }
        case .photos: ["Pictures"]
        case .music: ["Music"]
        case .movies: ["Movies"]
        case .iCloud: ["Library/Mobile Documents"]  // only files downloaded to this Mac take space
        case .developer: ["Library/Developer"]
        case .macOS, .systemData: []
        }
    }
}

/// Where System Data goes. Apple shows one opaque number; these are the places it's actually made of.
enum SystemDataPart: String, CaseIterable, Identifiable {
    case appData, caches, hidden, systemWide, assets, systemFiles, supportVolumes

    var id: Self { self }

    var title: String {
        switch self {
        case .appData: "App data"
        case .caches: "Caches"
        case .hidden: "Hidden folders in your home"
        case .systemWide: "Apps and tools for all users"
        case .assets: "Downloaded system assets"
        case .systemFiles: "System files"
        case .supportVolumes: "macOS support volumes"
        }
    }

    var detail: String {
        switch self {
        case .appData: "Settings, databases and files apps keep in ~/Library, like Application Support"
        case .caches: "~/Library/Caches. Clean Up can remove most of it."
        case .hidden: "Tool data and caches like ~/.npm, ~/.cache and ~/.ollama"
        case .systemWide: "/Library, /opt and /usr/local: Homebrew, frameworks, shared app support"
        case .assets: "Simulator runtimes, Apple Intelligence models, voices and docs macOS downloads"
        case .systemFiles: "/private/var: logs, temporary files and system databases"
        case .supportVolumes: "Preboot and VM volumes: startup files, staged updates, swap"
        }
    }

    /// Relative to home unless absolute; support volumes are measured as whole volumes instead.
    fileprivate var paths: [String] {
        let home = (try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory())) ?? []
        let library = (try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory() + "/Library")) ?? []
        switch self {
        // Developer and Mobile Documents are their own categories.
        case .appData: return library.filter { !["Caches", "Developer", "Mobile Documents"].contains($0) }.map { "Library/" + $0 }
        case .caches: return ["Library/Caches"]
        case .hidden: return home.filter { $0.hasPrefix(".") }
        case .systemWide: return ["/Library", "/opt", "/usr/local"]
        case .assets: return ["/System/Volumes/Data/System/Library/AssetsV2"]
        case .systemFiles: return ["/private/var"]
        case .supportVolumes: return []
        }
    }
}

@MainActor @Observable final class StorageBreakdown {
    static let shared = StorageBreakdown()

    private(set) var sizes: [StorageCategory: Int64] = [:]
    private(set) var systemParts: [SystemDataPart: Int64] = [:]
    private(set) var calculating = false
    private(set) var updated: Date?

    private init() {
        // The last result is kept across launches: a full pass reads every file in your home folder (millions in a
        // big code folder), so it's redone at most once a day, or when you ask.
        let saved = UserDefaults.standard.dictionary(forKey: Prefs.storageBreakdown) as? [String: Int64] ?? [:]
        sizes = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in StorageCategory(rawValue: k).map { ($0, v) } })
        systemParts = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in SystemDataPart(rawValue: k).map { ($0, v) } })
        updated = UserDefaults.standard.object(forKey: Prefs.storageBreakdownDate) as? Date
    }

    func refreshIfStale() {
        if sizes.isEmpty || systemParts.isEmpty || Date.now.timeIntervalSince(updated ?? .distantPast) > 86400 { recalculate() }
    }

    func recalculate() {
        guard !calculating else { return }
        calculating = true
        // Background priority: macOS throttles its disk access, so it's slower but doesn't get in your way.
        // ponytail: one resourceValues call per file (~100 s CPU for 9M files); getattrlistbulk measured ~40% less,
        // worth it if this ever runs more than daily.
        Task.detached(priority: .background) {
            var measured: [StorageCategory: Int64] = [:]
            for category in StorageCategory.allCases where !category.paths.isEmpty { measured[category] = Self.measure(category.paths) }
            measured[.macOS] = Self.volumeUsed("/")
            var parts: [SystemDataPart: Int64] = [:]
            for part in SystemDataPart.allCases where !part.paths.isEmpty { parts[part] = Self.measure(part.paths) }
            // Recovery isn't mounted, so it falls into "Snapshots and other".
            parts[.supportVolumes] = Self.volumeUsed("/System/Volumes/Preboot") + Self.volumeUsed("/System/Volumes/VM")
            let (final, finalParts) = (measured, parts)
            await MainActor.run {
                self.sizes = final
                self.systemParts = finalParts
                self.calculating = false
                self.updated = .now
                let saved = final.map { ($0.rawValue, $1) } + finalParts.map { ($0.rawValue, $1) }
                UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: saved), forKey: Prefs.storageBreakdown)
                UserDefaults.standard.set(Date.now, forKey: Prefs.storageBreakdownDate)
            }
        }
    }

    nonisolated private static func measure(_ paths: [String]) -> Int64 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return paths.reduce(0) { $0 + CleanScanner.scan($1.hasPrefix("/") ? URL(fileURLWithPath: $1) : home.appending(path: $1)).size }
    }

    /// Space used by one APFS volume, like the sealed macOS system volume at "/". statfs reports the whole
    /// container, so ask for the volume's own figure like df does.
    nonisolated private static func volumeUsed(_ path: String) -> Int64 {
        var attrs = attrlist(
            bitmapcount: u_short(ATTR_BIT_MAP_COUNT), reserved: 0, commonattr: 0,
            volattr: attrgroup_t(ATTR_VOL_INFO) | attrgroup_t(ATTR_VOL_SPACEUSED), dirattr: 0, fileattr: 0, forkattr: 0)
        var buffer = [UInt8](repeating: 0, count: 16)  // UInt32 length, then the off_t
        guard getattrlist(path, &attrs, &buffer, buffer.count, 0) == 0 else { return 0 }
        return buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
    }

    /// Category sizes for a disk with `used` bytes in use, System Data being the rest, largest categories first
    /// with macOS and System Data last, as in System Settings.
    func segments(used: Int64) -> [(StorageCategory, Int64)] {
        guard !sizes.isEmpty else { return [] }
        var all = sizes
        all[.systemData] = systemDataSize(used: used)
        let ordered = StorageCategory.allCases.filter { $0 != .macOS && $0 != .systemData }.sorted {
            all[$0, default: 0] > all[$1, default: 0]
        }
        return (ordered + [.macOS, .systemData]).compactMap { c in all[c].flatMap { $0 > 0 ? (c, $0) : nil } }
    }

    /// Everything used that isn't another category. At least the parts Sonar measured: macOS counts purgeable caches
    /// as available space, so they can add up to more than the leftover.
    func systemDataSize(used: Int64) -> Int64 {
        max(used - sizes.values.reduce(0, +), systemParts.values.reduce(0, +))
    }

    /// System Data's parts, largest first, plus whatever Sonar couldn't attribute (`nil`): local snapshots,
    /// Recovery, and folders it can't read.
    func systemBreakdown(used: Int64) -> [(SystemDataPart?, Int64)] {
        let parts: [(SystemDataPart?, Int64)] = systemParts.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map {
            ($0.key, $0.value)
        }
        let other = systemDataSize(used: used) - systemParts.values.reduce(0, +)
        return other > 0 ? parts + [(nil, other)] : parts
    }
}
