import SwiftUI

/// The dashboard's time range. Stored in seconds under `Prefs.dashboardRange`.
enum TimeRange: Int, CaseIterable, Identifiable {
    case minute = 60, fiveMinutes = 300, fifteenMinutes = 900, halfHour = 1800, hour = 3600

    var id: Int { rawValue }

    var short: String {
        switch self {
        case .minute: "1m"
        case .fiveMinutes: "5m"
        case .fifteenMinutes: "15m"
        case .halfHour: "30m"
        case .hour: "1h"
        }
    }

    var long: String {
        switch self {
        case .minute: "Last minute"
        case .fiveMinutes: "Last 5 minutes"
        case .fifteenMinutes: "Last 15 minutes"
        case .halfHour: "Last 30 minutes"
        case .hour: "Last hour"
        }
    }

    /// Spacing of the time axis labels, in seconds.
    var tickSeconds: Double {
        switch self {
        case .minute: 15
        case .fiveMinutes: 60
        case .fifteenMinutes: 300
        case .halfHour: 600
        case .hour: 900
        }
    }

    /// Clock-aligned tick times (e.g. 3:35, 3:40…) inside the range, leaving out any close enough to the right
    /// edge that its label would be cut off.
    func ticks(endingAt end: Date) -> [Date] {
        let start = end.timeIntervalSince1970 - Double(rawValue)
        let last = end.timeIntervalSince1970 - Double(rawValue) * 0.12
        var t = (start / tickSeconds).rounded(.up) * tickSeconds
        var ticks: [Date] = []
        while t <= last {
            ticks.append(Date(timeIntervalSince1970: t))
            t += tickSeconds
        }
        return ticks
    }
}
