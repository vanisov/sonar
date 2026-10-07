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
    var paths: [String] {
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
