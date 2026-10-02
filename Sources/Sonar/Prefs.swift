import Foundation
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
    static let panelSparkline = "panelSparklineSamples"
    static let panelCardClick = "panelCardOpensDashboard"

    // Dashboard
    static let dashboardOpenTo = "dashboardOpenTo"  // "last" or a section id
    static let dashboardLastSection = "dashboardLastSection"
    static let dashboardRange = "dashboardRange"  // seconds
    static let chartFilled = "chartFilled"
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

enum Appearance: String, CaseIterable {
    case system, light, dark

    var title: String { rawValue.capitalized }

    func apply() {
        NSApp.appearance =
            switch self {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
    }
}

enum TemperatureUnit: String {
    case celsius = "C", fahrenheit = "F"

    static let storageKey = "temperatureUnit"
    static var system: TemperatureUnit { Locale.current.measurementSystem == .us ? .fahrenheit : .celsius }
    static var current: TemperatureUnit {
        UserDefaults.standard.string(forKey: storageKey).flatMap(TemperatureUnit.init) ?? system
    }

    /// Sensors report Celsius; convert for display.
    static func convert(_ celsius: Double) -> Double { current == .celsius ? celsius : celsius * 9 / 5 + 32 }

    /// "58 °C" / "136 °F"
    static func format(_ celsius: Double, decimals: Int = 0) -> String {
        "\(convert(celsius).formatted(.number.precision(.fractionLength(decimals)))) °\(current.rawValue)"
    }
}

/// Number formatting that follows the Units settings.
enum Fmt {
    /// Storage sizes: GB like Finder (1000) or GiB (1024).
    static func storage<T: BinaryInteger>(_ bytes: T) -> String {
        let v = Int64(bytes)
        return Prefs.bool(Prefs.storageBinary, default: false)
            ? v.formatted(.byteCount(style: .binary, spellsOutZero: false))
            : v.formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    /// Memory sizes, like Activity Monitor.
    static func memory<T: BinaryInteger>(_ bytes: T) -> String {
        Int64(bytes).formatted(.byteCount(style: .memory, spellsOutZero: false))
    }

    /// Throughput in bytes/s or bits/s.
    static func rate(_ bytesPerSecond: Double) -> String {
        let v = max(bytesPerSecond, 0)
        if Prefs.bool(Prefs.networkBits, default: false) {
            let bits = v * 8
            let units: [(Double, String)] = [(1e9, "Gb/s"), (1e6, "Mb/s"), (1e3, "kb/s")]
            for (scale, unit) in units where bits >= scale {
                return "\((bits / scale).formatted(.number.precision(.significantDigits(1...3)))) \(unit)"
            }
            return "\(Int(bits)) b/s"
        }
        return Int64(v).formatted(.byteCount(style: .file, spellsOutZero: false)) + "/s"
    }

    static func percent(_ v: Double, decimals: Int = 0) -> String {
        "\(v.formatted(.number.precision(.fractionLength(decimals))))%"
    }

    /// "13d 6h" / "3h 12m"
    static func uptime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, h = m / 60, d = h / 24
        return d > 0 ? "\(d)d \(h % 24)h" : "\(h)h \(m % 60)m"
    }

    /// "293.11 GB" -> ("293.11", "GB")
    static func split(_ s: String) -> (String, String) {
        let parts = s.split(whereSeparator: \.isWhitespace)
        return (String(parts.first ?? ""), parts.dropFirst().joined(separator: " "))
    }
}
