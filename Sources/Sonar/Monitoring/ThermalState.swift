import SwiftUI

enum ThermalState {
    case nominal, fair, serious, critical

    static var current: ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        default: .nominal
        }
    }

    var title: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        }
    }

    var color: Color {
        switch self {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }
}
