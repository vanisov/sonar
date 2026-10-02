import SwiftUI

struct SensorsPage: View {
    let sensors: [Sensor]

    var body: some View {
        List {
            ForEach(Sensor.groupOrder, id: \.self) { group in
                let rows = sensors.filter { $0.group == group }
                if !rows.isEmpty {
                    Section(group) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, sensor in
                            HStack(spacing: 12) {
                                Text("\(group) \(i + 1)")
                                Text(sensor.id).font(.caption.monospaced()).foregroundStyle(.tertiary)
                                Spacer()
                                Sparkline(values: sensor.history, tint: .orange, maxValue: nil, window: 150).frame(width: 140, height: 20)
                                Text(TemperatureUnit.format(sensor.value, decimals: 1)).monospacedDigit().frame(
                                    width: 76, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if sensors.isEmpty { ContentUnavailableView("No temperature sensors found", systemImage: "thermometer.medium.slash") }
        }
    }
}
