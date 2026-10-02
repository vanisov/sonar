import SwiftUI

struct UnitsSettingsPane: View {
    @AppStorage(Prefs.temperatureUnit) private var unit = TemperatureUnit.system.rawValue
    @AppStorage(Prefs.storageBinary) private var binary = false
    @AppStorage(Prefs.networkBits) private var bits = false

    var body: some View {
        Form {
            Section {
                Picker("Temperature", selection: $unit) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                .pickerStyle(.segmented)
                Picker("Storage", selection: $binary) {
                    Text("GB, like Finder").tag(false)
                    Text("GiB").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("Network speed", selection: $bits) {
                    Text("Bytes (MB/s)").tag(false)
                    Text("Bits (Mb/s)").tag(true)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("GB counts 1,000 MB. GiB counts 1,024 MiB. Network providers usually quote speeds in bits.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 250)
    }
}
