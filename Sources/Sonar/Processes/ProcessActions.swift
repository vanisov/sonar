import SwiftUI

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
