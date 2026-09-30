import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let done: () -> Void
    @AppStorage(MenuBarItem.storageKey) private var items = MenuBarItem.defaults
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button(action: done) { Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Text("Settings").font(.system(size: 16, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Show in menu bar").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(MenuBarItem.allCases, id: \.self) { item in
                    Toggle(item.title, isOn: binding(for: item))
                }
            }
            .modifier(CardBackground())

            VStack(alignment: .leading, spacing: 8) {
                Text("General").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError {
                    Text(loginError).font(.system(size: 11)).foregroundStyle(.red)
                }
            }
            .modifier(CardBackground())
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func binding(for item: MenuBarItem) -> Binding<Bool> {
        Binding {
            items.split(separator: ",").contains(Substring(item.rawValue))
        } set: { on in
            var set = Set(items.split(separator: ",").map(String.init))
            if on { set.insert(item.rawValue) } else { set.remove(item.rawValue) }
            items = set.sorted().joined(separator: ",")
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item. Run Sonar from Sonar.app, not `swift run`."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
