import SwiftUI

/// Created on demand and torn down on close. A SwiftUI `Window` scene stays alive offscreen
/// and kept redrawing its charts while hidden.
@MainActor enum DashboardWindow {
    static var monitor: Monitor?
    private static var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?

    static func show(_ section: DashboardSection?, activate: Bool = true) {
        guard let monitor else { return }
        let nav = DashboardNavigation.shared
        if let section {
            nav.section = section
        } else if window == nil {
            let openTo = Prefs.string(Prefs.dashboardOpenTo, default: "last")
            let key = openTo == "last" ? Prefs.string(Prefs.dashboardLastSection, default: "overview") : openTo
            nav.section = DashboardSection(rawValue: key) ?? .overview
        }
        if window == nil {
            if activate, Prefs.bool(Prefs.showInDock, default: true) { NSApp.setActivationPolicy(.regular) }
            let host = NSHostingController(rootView: DashboardView(monitor: monitor))
            host.sceneBridgingOptions = .all  // lets SwiftUI install the toolbar, title and search field
            let w = NSWindow(contentViewController: host)
            w.title = "Sonar"
            w.styleMask.insert(.fullSizeContentView)
            w.toolbarStyle = .unified
            w.setContentSize(NSSize(width: 1080, height: 740))
            w.minSize = NSSize(width: 760, height: 520)
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("SonarDashboard")
            if !w.setFrameUsingName("SonarDashboard") { w.center() }
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: w, queue: .main
            ) { note in
                MainActor.assumeIsolated {
                    if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
                    // AppKit can keep a closed window around; detach the SwiftUI tree so it stops updating.
                    (note.object as? NSWindow)?.contentViewController = nil
                    window = nil
                    DashboardNavigation.shared.query = ""
                    DashboardNavigation.shared.diskCleanUp = false
                    Cleaner.shared.reset()
                    NSApp.setActivationPolicy(.accessory)
                    resignActiveIfNoWindows(closing: note.object as? NSWindow)
                }
            }
            window = w
        }
        guard activate else {
            window?.orderBack(nil)  // screenshots: on screen but behind everything, without taking focus
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static var windowNumber: Int? { window?.windowNumber }
}
