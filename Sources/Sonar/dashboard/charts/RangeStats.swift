import SwiftUI

/// Min / Average / Max for the visible range.
struct RangeStats: View {
    let times: Ring<Date>
    let values: Ring<Float>
    let format: (Double) -> String
    @AppStorage(Prefs.dashboardRange) private var range = TimeRange.fifteenMinutes.rawValue

    var body: some View {
        if let s = VisiblePoints(times: times, lead: nil, range: Double(range)).stats(values) {
            HStack(spacing: 8) {
                stat("Min", s.min)
                stat("Average", s.avg)
                stat("Max", s.max)
            }
        }
    }

    private func stat(_ label: String, _ v: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(format(v)).font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
