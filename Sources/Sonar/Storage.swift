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

@MainActor @Observable final class StorageBreakdown {
    static let shared = StorageBreakdown()

    private(set) var sizes: [StorageCategory: Int64] = [:]
    private(set) var calculating = false
    private(set) var updated: Date?

    private init() {
        // The last result is kept across launches: a full pass reads every file in your home folder (millions in a
        // big code folder), so it's redone at most once a day, or when you ask.
        let saved = UserDefaults.standard.dictionary(forKey: Prefs.storageBreakdown) as? [String: Int64] ?? [:]
        sizes = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in StorageCategory(rawValue: k).map { ($0, v) } })
        updated = UserDefaults.standard.object(forKey: Prefs.storageBreakdownDate) as? Date
    }

    func refreshIfStale() {
        if sizes.isEmpty || Date.now.timeIntervalSince(updated ?? .distantPast) > 86400 { recalculate() }
    }

    func recalculate() {
        guard !calculating else { return }
        calculating = true
        // Background priority: macOS throttles its disk access, so it's slower but doesn't get in your way.
        // ponytail: one resourceValues call per file (~100 s CPU for 9M files); getattrlistbulk measured ~40% less,
        // worth it if this ever runs more than daily.
        Task.detached(priority: .background) {
            let home = FileManager.default.homeDirectoryForCurrentUser
            var measured: [StorageCategory: Int64] = [:]
            for category in StorageCategory.allCases where !category.paths.isEmpty {
                let urls = category.paths.map { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : home.appending(path: $0) }
                measured[category] = urls.reduce(0) { $0 + CleanScanner.scan($1).size }
            }
            measured[.macOS] = Self.systemVolumeUsed()
            let final = measured
            await MainActor.run {
                self.sizes = final
                self.calculating = false
                self.updated = .now
                UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: final.map { ($0.rawValue, $1) }), forKey: Prefs.storageBreakdown)
                UserDefaults.standard.set(Date.now, forKey: Prefs.storageBreakdownDate)
            }
        }
    }

    /// Space used by the sealed macOS system volume. statfs reports the whole APFS container, so ask for the
    /// volume's own figure like df does.
    nonisolated private static func systemVolumeUsed() -> Int64 {
        var attrs = attrlist(
            bitmapcount: u_short(ATTR_BIT_MAP_COUNT), reserved: 0, commonattr: 0,
            volattr: attrgroup_t(ATTR_VOL_INFO) | attrgroup_t(ATTR_VOL_SPACEUSED), dirattr: 0, fileattr: 0, forkattr: 0)
        var buffer = [UInt8](repeating: 0, count: 16)  // UInt32 length, then the off_t
        guard getattrlist("/", &attrs, &buffer, buffer.count, 0) == 0 else { return 0 }
        return buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
    }

    /// Category sizes for a disk with `used` bytes in use, System Data being the rest, largest categories first
    /// with macOS and System Data last, as in System Settings.
    func segments(used: Int64) -> [(StorageCategory, Int64)] {
        guard !sizes.isEmpty else { return [] }
        let known = sizes.values.reduce(0, +)
        var all = sizes
        all[.systemData] = max(0, used - known)
        let ordered = StorageCategory.allCases.filter { $0 != .macOS && $0 != .systemData }.sorted {
            all[$0, default: 0] > all[$1, default: 0]
        }
        return (ordered + [.macOS, .systemData]).compactMap { c in all[c].flatMap { $0 > 0 ? (c, $0) : nil } }
    }
}
