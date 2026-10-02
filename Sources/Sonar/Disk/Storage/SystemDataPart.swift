import SwiftUI

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
    var paths: [String] {
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
