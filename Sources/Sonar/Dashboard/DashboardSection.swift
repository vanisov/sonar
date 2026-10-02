import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable, Hashable {
    case overview, cpu, gpu, memory, disk, network, sensors, fans, apps, system

    static let metrics: [DashboardSection] = [.cpu, .gpu, .memory, .disk, .network, .sensors, .fans]
    var id: Self { self }
    var isMetric: Bool { Self.metrics.contains(self) }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .network: "Network"
        case .sensors: "Sensors"
        case .fans: "Fans"
        case .apps: "Processes"
        case .system: "This Mac"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.xyaxis.line"
        case .cpu: "cpu"
        case .gpu: "square.stack.3d.up"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "network"
        case .sensors: "thermometer.medium"
        case .fans: "fan"
        case .apps: "list.bullet.rectangle"
        case .system: "laptopcomputer"
        }
    }

    var tint: Color {
        switch self {
        case .overview, .apps, .system: .signal
        case .cpu: .blue
        case .gpu: .pink
        case .memory: .purple
        case .disk: .orange
        case .network: .green
        case .sensors: .red
        case .fans: .teal
        }
    }
}
