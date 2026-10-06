import SwiftUI

/// ⌘F results across sections, apps and sensors. Clicking one opens its page.
struct SearchResults: View {
    let monitor: Monitor
    let query: String
    let open: (_ section: DashboardSection, _ keepQuery: Bool) -> Void

    var body: some View {
        let q = query.lowercased()
        let sections = DashboardSection.allCases.filter { $0.title.lowercased().contains(q) }
        let apps = monitor.apps.filter { $0.name.lowercased().contains(q) }
        let sensors = monitor.sensors.filter { "\($0.group) \($0.id)".lowercased().contains(q) }
        List {
            if !sections.isEmpty {
                Section("Sections") {
                    ForEach(sections) { s in
                        result {
                            open(s, false)
                        } label: {
                            Label(s.title, systemImage: s.symbol)
                        }
                    }
                }
            }
            if !apps.isEmpty {
                Section("Apps") {
                    ForEach(apps) { app in
                        result {
                            open(.apps, true)
                        } label: {
                            HStack {
                                if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                                Text(app.name)
                                Spacer()
                                Text("\(Fmt.memory(app.memory)) · \(Fmt.percent(app.cpu, decimals: 1))").foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            if !sensors.isEmpty {
                Section("Sensors") {
                    ForEach(sensors.prefix(20)) { s in
                        result {
                            open(.sensors, false)
                        } label: {
                            HStack {
                                Text(s.group)
                                Text(s.id).font(.caption.monospaced()).foregroundStyle(.tertiary)
                                Spacer()
                                Text(TemperatureUnit.format(s.value, decimals: 1)).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty && apps.isEmpty && sensors.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func result(_ action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) { label().contentShape(Rectangle()) }.buttonStyle(.plain)
    }
}
