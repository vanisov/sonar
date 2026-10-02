import SwiftUI

struct NetworkPage: View {
    let monitor: Monitor
    @State private var interfaces = NetworkInterface.all()

    var body: some View {
        let m = monitor
        page {
            DashCard(title: "Throughput", symbol: "network", tint: .green) {
                HStack(spacing: 24) {
                    BigValue(value: Fmt.rate(m.down), caption: "Download", dot: .green)
                    BigValue(value: Fmt.rate(m.up), caption: "Upload", dot: .teal)
                }
                HistoryChart(
                    times: m.times,
                    series: [
                        ChartSeries(name: "Down", values: m.downHistory, color: .green),
                        ChartSeries(name: "Up", values: m.upHistory, color: .teal),
                    ],
                    height: 210, axis: { Fmt.rate($0) })
                RangeStats(times: m.times, values: m.downHistory, format: { Fmt.rate($0) })
            }
            LazyVGrid(columns: two, spacing: 14) {
                DashCard(title: "Interfaces", symbol: "point.3.connected.trianglepath.dotted", tint: .green) {
                    VStack(spacing: 0) {
                        ForEach(interfaces, id: \.bsd) { i in
                            keyValue("\(i.name) (\(i.bsd))", i.address ?? "Not connected", dot: i.address == nil ? .secondary : .green)
                        }
                    }
                }
                DashCard(title: "Since boot", symbol: "clock.arrow.circlepath", tint: .green) {
                    VStack(spacing: 0) {
                        keyValue("Downloaded", Fmt.storage(m.networkTotal.down))
                        keyValue("Uploaded", Fmt.storage(m.networkTotal.up))
                    }
                }
            }
        }
        .onAppear { interfaces = NetworkInterface.all() }
    }
}
