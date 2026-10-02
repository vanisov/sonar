import SwiftUI

/// Sonar's Settings window: native toolbar tabs, created when opened and torn down on close.
/// (SwiftUI's Settings scene keeps its window, and everything in it, alive after closing.)
@MainActor enum SettingsWindow {
    private static var window: NSWindow?

    static func open() {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            func add(_ title: String, _ symbol: String, _ view: some View) {
                let host = NSHostingController(rootView: view.frame(width: 580))
                host.sizingOptions = .preferredContentSize  // the window resizes to each tab
                host.title = title  // becomes the window title while the tab is selected
                let item = NSTabViewItem(viewController: host)
                item.label = title
                item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
                tabs.addTabViewItem(item)
            }
            add("General", "gearshape", GeneralSettingsPane())
            add("Menu Bar", "menubar.rectangle", MenuBarSettingsPane())
            add("Panel", "rectangle.grid.2x2", PanelSettingsPane())
            add("Dashboard", "chart.xyaxis.line", DashboardSettingsPane())
            add("Units", "ruler", UnitsSettingsPane())
            add("About", "info.circle", AboutSettingsPane())
            let w = NSWindow(contentViewController: tabs)
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { note in
                MainActor.assumeIsolated {
                    (note.object as? NSWindow)?.contentViewController = nil
                    window = nil
                    resignActiveIfNoWindows(closing: note.object as? NSWindow)
                }
            }
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
