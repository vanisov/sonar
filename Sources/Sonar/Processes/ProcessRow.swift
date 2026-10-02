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
