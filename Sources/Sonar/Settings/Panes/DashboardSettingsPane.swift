import SwiftUI

struct DashboardSettingsPane: View {
    @AppStorage(Prefs.dashboardOpenTo) private var openTo = "last"
    @AppStorage(Prefs.dashboardRange) private var range = 900
    @AppStorage(Prefs.chartFilled) private var filled = true
    @AppStorage(Prefs.overlayTemperature) private var overlay = true
    @AppStorage(Prefs.cpuTempSource) private var hottest = false
    @AppStorage(Prefs.confirmForce) private var confirmForce = true
    @AppStorage(Prefs.showSystemProcesses) private var showSystem = true

    var body: some View {
        Form {
            Section {
                Picker("Open to", selection: $openTo) {
                    Text("Last section viewed").tag("last")
                    Text("Overview").tag(DashboardSection.overview.rawValue)
                    Text("Processes").tag(DashboardSection.apps.rawValue)
                }
                Picker("Default time range", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.short).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Section("Charts") {
                Picker("Style", selection: $filled) {
                    Text("Filled").tag(true)
                    Text("Line").tag(false)
                }
                .pickerStyle(.segmented)
                Toggle("Overlay temperature on CPU and GPU usage", isOn: $overlay)
            }
            Section {
                Picker("CPU temperature", selection: $hottest) {
                    Text("Average of all CPU sensors").tag(false)
                    Text("Hottest CPU sensor").tag(true)
                }
            } footer: {
                Text("Also used in the panel and the menu bar.").foregroundStyle(.secondary)
            }
            Section {
                Toggle("Confirm before Force Quit and Force End", isOn: $confirmForce)
                Toggle("Show other users' and system processes", isOn: $showSystem)
            } header: {
                Text("Processes")
            } footer: {
                Text("macOS doesn't let Sonar read or end other users' processes, so they're listed with a lock.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 530)
    }
}
