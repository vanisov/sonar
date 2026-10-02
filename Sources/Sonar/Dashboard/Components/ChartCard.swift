import SwiftUI

/// Large chart with its current value and min / average / max.
struct ChartCard: View {
    let title: String
    let symbol: String
    let tint: Color
    var trailing: String?
    let value: String
    var unit = ""
    let times: Ring<Date>
    let series: [ChartSeries]
    var domain: ClosedRange<Double>?
    let axis: (Double) -> String

    var body: some View {
        DashCard(title: title, symbol: symbol, tint: tint, trailing: trailing) {
            BigValue(value: value, unit: unit)
            HistoryChart(times: times, series: series, domain: domain, height: 210, axis: axis)
            if let lead = series.first { RangeStats(times: times, values: lead.values, format: { axis($0 / lead.scale) }) }
        }
    }
}
