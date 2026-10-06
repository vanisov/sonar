import SwiftUI

struct MenuBarLabel: View {
    let monitor: Monitor
    // Read so the label redraws when any of these change.
    @AppStorage(Prefs.menuBarItems) private var items = MenuBarItem.defaults
    @AppStorage(Prefs.menuBarOrder) private var order = ""
    @AppStorage(Prefs.menuBarStyles) private var styles = ""
    @AppStorage(Prefs.menuBarDecimals) private var decimals = 0
    @AppStorage(Prefs.menuBarHighlight) private var highlight = true
    @AppStorage(TemperatureUnit.storageKey) private var unit = TemperatureUnit.system.rawValue

    private static var cached: (key: String, image: NSImage)?

    var body: some View {
        let parts = MenuBarConfig.parts { $0.part(monitor, decimals: decimals) }
        // Values usually round to the same text between samples; only redraw when it actually changes.
        let key = parts.map { "\($0.symbol ?? "")\($0.value ?? "")\($0.level)" }.joined(separator: " ") + "\(highlight)"
        if Self.cached?.key != key {
            Self.cached = (key, parts.isEmpty ? MenuBarLogo.image : MenuBarConfig.render(parts, highlight: highlight))
        }
        return Image(nsImage: Self.cached!.image)
    }
}
