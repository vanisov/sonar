import SwiftUI

/// A card in the panel. Order and visibility are stored as "cpu,gpu,-memory,…" where "-" means hidden.
enum PanelCard: String, CaseIterable, Identifiable {
    case cpu, gpu, memory, network, disk, fans, apps  // disk and fans next to each other, so they share a row

    static let defaults = allCases.map(\.rawValue).joined(separator: ",")
    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .network: "Network"
        case .fans: "Fans"
        case .apps: "Using the most"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "square.stack.3d.up"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "network"
        case .fans: "fan"
        case .apps: "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: .blue
        case .gpu: .pink
        case .memory: .purple
        case .disk: .orange
        case .network: .green
        case .fans: .teal
        case .apps: .indigo
        }
    }

    /// Disk and fans are half-width and pair up; the rest take a full row.
    var isCompact: Bool { self == .disk || self == .fans }

    var section: DashboardSection {
        switch self {
        case .cpu: .cpu
        case .gpu: .gpu
        case .memory: .memory
        case .disk: .disk
        case .network: .network
        case .fans: .fans
        case .apps: .apps
        }
    }

    private static var saved: [(card: PanelCard, shown: Bool)] {
        Prefs.string(Prefs.panelCards, default: defaults).split(separator: ",").compactMap { token in
            let hidden = token.hasPrefix("-")
            return PanelCard(rawValue: String(hidden ? token.dropFirst() : token)).map { ($0, !hidden) }
        }
    }

    static var order: [PanelCard] {
        let known = saved.map(\.card)
        return known + allCases.filter { !known.contains($0) }
    }

    static var enabled: [PanelCard] {
        let hidden = Set(saved.filter { !$0.shown }.map(\.card))
        return order.filter { !hidden.contains($0) }
    }

    static func encode(order: [PanelCard], shown: Set<PanelCard>) -> String {
        order.map { shown.contains($0) ? $0.rawValue : "-" + $0.rawValue }.joined(separator: ",")
    }
}
