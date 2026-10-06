import SwiftUI

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
