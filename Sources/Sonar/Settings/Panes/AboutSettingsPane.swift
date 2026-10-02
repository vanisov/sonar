import SwiftUI

struct AboutSettingsPane: View {
    @AppStorage(Prefs.checkForUpdates) private var autoCheck = false
    @AppStorage(Prefs.installUpdates) private var autoInstall = false
    @AppStorage(Prefs.betaUpdates) private var beta = false
    private let updater = Updater.shared
    private let repo = URL(string: "https://github.com/\(Updater.repo)")!

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 22) {
                AppMark(size: 104)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sonar for macOS").font(.title3.bold())
                    Text("Version \(Updater.currentVersion)").foregroundStyle(.secondary).monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Link("Release Notes", destination: repo.appending(path: "blob/main/CHANGELOG.md"))
                        Link("Acknowledgements", destination: repo.appending(path: "blob/main/README.md#thanks"))
                        Link("Privacy", destination: repo.appending(path: "blob/main/README.md#privacy"))
                        Link("MIT License", destination: repo.appending(path: "blob/main/LICENSE"))
                        Link("Source Code", destination: repo)
                    }
                    .padding(.top, 6)
                    Button("Report an Issue…") { NSWorkspace.shared.open(repo.appending(path: "issues/new/choose")) }
                        .padding(.top, 6)
                }
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(
                    "Sonar collects no data and has no analytics. The only network request it makes is the update check below, and only if you turn it on."
                )
                Text("© 2026 Vlad Anisov. Released under the MIT License.")
                Text("Sonar is not affiliated with Apple Inc. Apple, Mac, macOS and Apple silicon are trademarks of Apple Inc.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 460)

            if let notes = ReleaseNotes.current {
                DisclosureGroup("What's new in \(Updater.currentVersion)") {
                    Text(notes).font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }
                .frame(maxWidth: 480)
            }

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Automatically check for updates", isOn: $autoCheck)
                    Toggle("Install updates automatically", isOn: $autoInstall).disabled(!autoCheck)
                    Picker("Update to", selection: $beta) {
                        Text("Stable releases").tag(false)
                        Text("Beta releases").tag(true)
                    }
                    .fixedSize()
                }
                .toggleStyle(.checkbox)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    statusText
                    if case .available = updater.status {
                        Button("Install and Relaunch") { Task { await updater.install() } }
                    } else {
                        Button("Check Now") { Task { await updater.check() } }
                            .disabled(updater.status == .checking || updater.status == .installing)
                    }
                    if let page = updater.latest?.page { Link("Release Notes", destination: page) }
                }
                .font(.callout)
                .multilineTextAlignment(.trailing)
            }
            Text("Checks GitHub releases once a day. Nothing else is sent.").font(.caption).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(width: 580)
    }

    @ViewBuilder private var statusText: some View {
        switch updater.status {
        case .idle:
            Text(updater.lastChecked.map { "Last checked \($0.formatted(.relative(presentation: .named)))" } ?? "Not checked yet")
                .foregroundStyle(.secondary)
        case .checking: Text("Checking…").foregroundStyle(.secondary)
        case .upToDate: Text("Sonar \(Updater.currentVersion) is up to date").foregroundStyle(.secondary)
        case .available(let v): Text("Sonar \(v) is available").bold()
        case .installing: Text("Installing…").foregroundStyle(.secondary)
        case .failed(let message): Text(message).foregroundStyle(.red).frame(maxWidth: 240, alignment: .trailing)
        }
    }
}
