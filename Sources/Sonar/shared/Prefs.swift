import SwiftUI

/// Every setting's key and default, in one place. Views bind with `@AppStorage(Prefs.x)`; non-view code reads
/// `Prefs.value(...)`.
enum Prefs {
    // General
    static let showInDock = "showInDockWithDashboard"
    static let appearance = "appearance"  // Appearance.rawValue
    static let dashboardShortcut = "shortcutDashboard"  // Shortcut.storage, "" = none

    // Menu bar
    static let menuBarItems = MenuBarItem.storageKey  // enabled items, comma-separated
    static let menuBarOrder = "menuBarOrder"  // all items, comma-separated
    static let menuBarStyles = "menuBarStyles"  // "cpu=value,fan=icon"
    static let menuBarDecimals = "menuBarDecimals"
    static let menuBarHighlight = "menuBarHighlight"

    // Panel
    static let panelCards = "panelCards"  // enabled cards in order, comma-separated
    static let panelTopApps = "panelTopApps"
    static let panelGraphLength = "panelSparklineSamples"  // key kept from when it was "Sparkline length"
    static let panelCardClick = "panelCardOpensDashboard"

    // Dashboard
    static let dashboardOpenTo = "dashboardOpenTo"  // "last" or a section id
    static let dashboardLastSection = "dashboardLastSection"
    static let dashboardRange = "dashboardRange"  // seconds
    static let overlayTemperature = "overlayTemperature"
    static let cpuTempSource = "cpuTempHottest"  // false = average

    // Processes
    static let confirmForce = "confirmForceQuit"
    static let showSystemProcesses = "showSystemProcesses"

    // Disk
    static let storageBreakdown = "storageBreakdown"  // last measured category sizes, [category: bytes]
    static let storageBreakdownDate = "storageBreakdownDate"

    // Units
    static let temperatureUnit = TemperatureUnit.storageKey
    static let storageBinary = "storageBinary"
    static let networkBits = "networkBits"

    // Updates
    static let checkForUpdates = "checkForUpdates"
    static let installUpdates = "installUpdates"
    static let betaUpdates = "betaUpdates"
    static let lastUpdateCheck = "lastUpdateCheck"

    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }

    static func int(_ key: String, default value: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? value
    }

    static func string(_ key: String, default value: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? value
    }

    /// Clears every Sonar setting (Settings → General → Restore Defaults).
    static func reset() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}
