import SwiftUI

/// After Sonar's last window closes, hand focus back to the previous app. Otherwise macOS keeps treating Sonar as the
/// active app and its services keep waking it up (~1 wake-up a second, measured with perf.sh).
@MainActor func resignActiveIfNoWindows(closing: NSWindow?) {
    let open = NSApp.windows.contains { $0 !== closing && $0.isVisible && !$0.className.contains("StatusBar") }
    if !open { NSApp.hide(nil) }
}
