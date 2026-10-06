import ServiceManagement
import SwiftUI

struct GeneralSettingsPane: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @AppStorage(Prefs.showInDock) private var showInDock = true
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system.rawValue
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch Sonar at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).foregroundStyle(.red).font(.callout) }
                Toggle("Show Sonar in the Dock while the dashboard is open", isOn: $showInDock)
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, v in Appearance(rawValue: v)?.apply() }
            }
            Section {
                LabeledContent("Open the dashboard") { ShortcutRecorder(key: Prefs.dashboardShortcut) }
            } header: {
                Text("Keyboard shortcut")
            } footer: {
                Text("Works from any app. Click it, then press the keys. Esc cancels, Delete removes it.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Restore Default Settings…") { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .frame(height: 400)
        .confirmationDialog("Restore all settings to their defaults?", isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive) {
                Prefs.reset()
                Appearance.system.apply()
                Hotkeys.reload()
            }
        } message: {
            Text("Your menu bar, panel, dashboard, unit and update choices go back to how Sonar ships.")
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update the login item. Launch at login works when Sonar runs from Sonar.app."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
